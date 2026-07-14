import Lean
import Std.Http.Data.Method
import Routing.Route
import Routing.Url

/-!
`routes!`: a nested route-table macro that keeps a pattern's text written exactly once,
regardless of how many methods or nested sub-paths share it, and generates the matching `Urls`
reverse-routing bundle alongside it. See `docs/reverse-routing-macro-plan.md` (design rationale,
"Option C") and `docs/reverse-routing-macro-tasks.md` Phase 2 (execution notes, spike findings)
for full context; this is the implementation.

## Grammar

```
routes! (db : SQLite) : Todo.Urls where
  "/" as index { get => pageHandler .all }
  "/todos" as todos {
    post => addHandler
    "/:id:Nat" as todo {
      put => saveHandler
      delete => deleteHandler
    }
  }
```

A `routes!` body is a list of *fragments*. Each fragment is a pattern-string literal, an optional
`as name`, and a brace-delimited body mixing `method => handler` entries and further nested
fragments. A node's *resolved* pattern is its parent's resolved segments `++` its own local
segments (`List PathSeg` append, not string concatenation -- see the plan doc §2 for why this
sidesteps the string-join edge cases `Pattern.lean`'s own parser has to worry about).

## What it expands to

Two `def`s, spliced into the file the `routes!` invocation is written in (not hygienically scoped
-- see `mkUrlsIdent`/`mkRoutesIdent` below for why that's a deliberate, load-bearing choice):

- `def urls : <urlsType> := { <name> := routeUrl "<resolved pattern>", ... }` -- one field per
  `as`-named node anywhere in the tree, regardless of nesting depth or how many methods that node
  has.
- `def routes (db : <dbType>) := [ Route.<method> "<resolved pattern>" (<handler> urls db), ... ]`
  -- one element per `method => handler` entry anywhere in the tree.

Both are sugar over the existing, unchanged `Route.get`/`.post`/`.put`/`.delete`/`routeUrl`
primitives (`Routing/Route.lean`, `Routing/Url.lean`) -- this macro does not reimplement dispatch
or reverse routing, it only assembles the calls those primitives already provide, so a wrong-arity
or wrong-type handler is rejected by the very same `HandlerType`/elaborator machinery a
hand-written `Route.get "..." handler` call would hit, with the same quality of error (confirmed
by the throwaway spike behind this file, now pinned as `#guard_msgs` regressions below).

## Two things the spike found that the design doc's grammar sketch doesn't show

1. **`manyIndent`, not a bare `routeItem*`.** A handler `term` with nothing to stop it (no comma,
   no trailing token) happily continues parsing across a newline as a further application argument
   -- `f` immediately followed on the next line by `"/next" as ...` mis-parses as `f "/next"`
   (ordinary Lean multi-line-application syntax, ultimately because `argument`'s `checkColGt` check
   runs against whatever `withPosition` last saved, and without one of our own, that reference
   column is inherited from too far outside to reject a same-column sibling). `manyIndent` (i.e.
   `withPosition` + `checkColGe` per item, `Lean/Parser/Extra.lean`) anchors that reference column
   at each item list's own start, so a same-or-greater-column next item reliably ends the previous
   term. Confirmed broken without it, fixed with it, by direct compilation, not assumed.
2. **The emitted `def urls`/`def routes` need an explicit target type, and need `mkIdent` (not a
   literal name in a quotation).** Two independent gaps in the design doc's grammar sketch:
   - Lean's anonymous `{ field := val, ... }` structure-instance notation requires a *known*
     expected type; there is no such type available at a bare `def urls := { ... }` site with no
     ascription (confirmed directly: `def x := { a := 1, b := 2 }` with nothing to pin the type
     fails with "invalid \{...\} notation, expected type is not known", even when there's only one
     structure in scope with matching field names -- Lean does not search for a unique match). So
     `routes!`'s own syntax has to carry that type explicitly; simplest option that works is a
     `: <urlsType>` clause before `where`, e.g. `routes! (db : SQLite) : Todo.Urls where ...`.
   - A *literal* identifier written directly in a `` `(...) `` syntax quotation (e.g.
     `` `(def urls := ...) `` with `urls` typed as plain text) is macro-hygiene-scoped by default --
     it elaborates to a fresh, mangled name, not literally `urls`, and is therefore invisible to
     ordinary code elsewhere in the file (confirmed directly: a macro emitting `def foo := 42` this
     way leaves `foo` an "unknown identifier" everywhere outside that one macro expansion, even
     immediately below it in the same file). `mkIdent` bypasses hygiene for a specific name; this
     file uses `mkIdent `` `urls`` / `` `routes`` and splices those (`$urlsIdent`, `$routesIdent`)
     everywhere the two defs are named or referenced, rather than ever writing `urls`/`routes` as
     literal text inside a quotation.

## A load-bearing gap between the plan doc's illustration and Phase 1's shipped `Urls`

Per plan doc §3, a node contributes a `Urls` field *only* via an explicit `as name` -- there's no
implicit derivation from path text. The design doc's own worked example leaves `"/"`, `"/active"`,
`"/completed"` unnamed, but Phase 1 (`docs/reverse-routing-macro-tasks.md` §1.1, already shipped
and tested) gave `Todo.Urls` `index`/`active`/`completed` fields regardless -- so those three nodes
need `as index`/`as active`/`as completed` at the real call site (`Main.lean`, task 2.3) or the
generated `urls` value is missing required fields. Confirmed directly (the exact "Fields missing"
error Lean gives) rather than assumed; this is a correction to the illustration, not to `Urls`
itself -- Phase 1's field set is unchanged.
-/

namespace Routing

open Lean Elab Command Meta

/-- One node in a `routes!` tree: either a `method => handler` entry, or a further
`"pattern" (as name)? { ... }` fragment. The two productions share this single category (rather
than two separate ones for "top-level fragment" vs "nested item") because plan doc §2's whole point
is that nesting is uniform -- a node's body mixes method entries and child fragments freely at any
depth, including the top level. -/
declare_syntax_cat routeItem

/-- `get => handler`, `post => handler`, `put => handler`, `delete => handler`. -/
syntax ident " => " term : routeItem

/-- `"pattern" (as name)? { item* }`. See the module docstring for why `manyIndent`, not a bare
`routeItem*`, is required here. -/
syntax str (" as " ident)? " { " manyIndent(routeItem) " } " : routeItem

/-- `routes! (db : SQLite) : Todo.Urls where <items>`. See the module docstring for why the
`: <urlsType>` clause is necessary (not just stylistic). -/
syntax "routes! " "(" ident " : " term ")" " : " term " where " manyIndent(routeItem) : command

/-- One flattened `method => handler` entry, together with the resolved (parent-prefixed)
`List PathSeg` its pattern text resolves to. -/
private structure MethodEntry where
  method  : TSyntax `ident
  handler : TSyntax `term
  segs    : List PathSeg

/-- One `as name` node, together with its resolved `List PathSeg`. -/
private structure NamedNode where
  name : TSyntax `ident
  segs : List PathSeg

/-- Whether a `routeItem` method identifier names one of the four supported HTTP methods. -/
private def isKnownMethod (m : String) : Bool :=
  m = "get" || m = "post" || m = "put" || m = "delete"

/-- Walks a `routeItem` list, threading the accumulated parent `List PathSeg` down through nested
fragments, and flattens the tree into every `method => handler` entry (with its resolved segments)
and every `as`-named node (ditto) found anywhere in it.

Each fragment's local pattern text is parsed with `parsePattern` (never `parsePattern!`) and a
`none` result is a macro-time `throwErrorAt` pointing at that fragment's own string literal --
`parsePattern!`'s silent root-pattern fallback (`Pattern.lean`, Phase 0) is exactly the danger this
sidesteps: macro elaboration has real error-throwing that a plain `def` does not (plan doc §5). -/
private partial def processItems (parentSegs : List PathSeg) (items : Array (TSyntax `routeItem)) :
    CommandElabM (Array MethodEntry × Array NamedNode) := do
  let mut methodEntries : Array MethodEntry := #[]
  let mut namedNodes : Array NamedNode := #[]
  for item in items do
    match item with
    | `(routeItem| $m:ident => $h:term) =>
      if !isKnownMethod m.getId.toString then
        throwErrorAt m
          s!"routes!: unknown HTTP method '{m.getId}' -- expected one of get, post, put, delete"
      methodEntries := methodEntries.push { method := m, handler := h, segs := parentSegs }
    | `(routeItem| $s:str $[as $n:ident]? { $subItems* }) =>
      let localStr := s.getString
      let localSegs ←
        match parsePattern localStr with
        | some segs => pure segs
        | none =>
          throwErrorAt s
            s!"routes!: malformed route pattern fragment {localStr.quote} -- expected a leading \
              '/', no doubled/trailing '/', and every capture written as ':name:Nat' or \
              ':name:String'"
      let resolvedSegs := parentSegs ++ localSegs
      if let some name := n then
        namedNodes := namedNodes.push { name := name, segs := resolvedSegs }
      let (subMethods, subNamed) ← processItems resolvedSegs subItems
      methodEntries := methodEntries ++ subMethods
      namedNodes := namedNodes ++ subNamed
    | _ => throwErrorAt item "routes!: unrecognized item"
  return (methodEntries, namedNodes)

/-- Rejects two structural problems across the *whole* tree (not just siblings), per plan doc §5:
two nodes sharing an `as` name, and two different `as` names resolving to the same full pattern
(compared as resolved `List PathSeg`, not local text, since two fragments under different parents
could coincidentally render to the same full path). Both are macro-time errors pointing at the
second (later) offending node, not a redeclaration failure with a worse message. -/
private def checkNamedNodes (namedNodes : Array NamedNode) : CommandElabM Unit := do
  let mut seenNames : Std.HashMap String (List PathSeg) := {}
  let mut seenSegs : Array (List PathSeg × TSyntax `ident) := #[]
  for n in namedNodes do
    let nm := n.name.getId.toString
    if let some earlierSegs := seenNames[nm]? then
      throwErrorAt n.name
        s!"routes!: duplicate route name '{nm}' (already used for {renderPattern earlierSegs}) \
          -- every 'as' name must be unique across the whole tree"
    seenNames := seenNames.insert nm n.segs
    if let some (_, earlierName) := seenSegs.find? (fun (segs, _) => segs == n.segs) then
      throwErrorAt n.name
        s!"routes!: 'as {nm}' resolves to the same pattern ({renderPattern n.segs}) as \
          'as {earlierName.getId}' -- two names for one pattern defeats the point of naming it"
    seenSegs := seenSegs.push (n.segs, n.name)

elab_rules : command
  | `(routes! ($db : $dbTy) : $urlsTy where $items*) => do
    let (methodEntries, namedNodes) ← processItems [] items
    checkNamedNodes namedNodes
    let urlsIdent := mkIdent `urls
    let routesIdent := mkIdent `routes
    let urlsFields ← namedNodes.mapM fun n => do
      let patLit := Syntax.mkStrLit (renderPattern n.segs)
      `(routeUrl $patLit:str)
    let urlsNames := namedNodes.map (·.name)
    let urlsDef ← `(command| def $urlsIdent:ident : $urlsTy := { $[$urlsNames:ident := $urlsFields],* })
    elabCommand urlsDef
    let routeElems ← methodEntries.mapM fun e => do
      let patLit := Syntax.mkStrLit (renderPattern e.segs)
      let handlerApplied ← `($(e.handler) $urlsIdent $db)
      -- `Route.get`/`.post`/`.put`/`.delete` are literal-only macros (`Routing/Route.lean`), not
      -- plain `def`s -- reached only via their own quotation form here, never via a generically
      -- constructed `ident`-headed application (which would look up a now-nonexistent constant).
      -- `isKnownMethod` was already checked true for every entry in `processItems`.
      match e.method.getId.toString with
      | "get" => `(Route.get $patLit $handlerApplied)
      | "post" => `(Route.post $patLit $handlerApplied)
      | "put" => `(Route.put $patLit $handlerApplied)
      | "delete" => `(Route.delete $patLit $handlerApplied)
      | m => throwErrorAt e.method s!"routes!: unknown HTTP method '{m}'"
    let routesList ← `([ $routeElems,* ])
    let routesDef ← `(command| def $routesIdent:ident ($db : $dbTy) := $routesList)
    elabCommand routesDef

/-! ## Tests

`Routing` stays app-framework-agnostic (module docstring, plan doc §7) -- it can't depend on
`Todo`/`SQLite`, so these use a toy `Urls`-shaped structure and a toy `Nat` standing in for `db`,
mirroring the shape a real consumer supplies without actually depending on one. Each negative test
lives in its own `namespace` purely to give its `routes!` invocation's generated `urls`/`routes` a
distinct fully-qualified name -- `routes!` deliberately does *not* hygienically scope those names
(module docstring), so two invocations emitting bare `urls`/`routes` in the same namespace would
collide exactly like two hand-written `def urls`s would. -/

private structure TestUrls where
  root    : String
  item    : Nat → String
  special : String

private def rootHandler (_urls : TestUrls) (_db : Nat) : String := "root"
private def itemGetHandler (_urls : TestUrls) (_db : Nat) (id : Nat) : String := s!"get-item-{id}"
private def itemPutHandler (_urls : TestUrls) (_db : Nat) (id : Nat) : String := s!"put-item-{id}"
private def specialHandler (_urls : TestUrls) (_db : Nat) : String := "special"
private def badArityHandler (_urls : TestUrls) (_db : Nat) (_id : Nat) (_extra : String) : String :=
  "oops"

-- The main positive regression: 2-3 levels of nesting, a captured node with two methods sharing
-- one written pattern (`PUT`/`GET` on `/items/:id:Nat`), and a same-arity literal/capture
-- collision (`/items/special` vs `/items/:id:Nat`) exercised through the macro's *actual*
-- flattened `dispatchTable` output -- plan doc §5's order-sensitivity risk, not just a manual
-- click-through.
namespace PositiveTest

routes! (db : Nat) : TestUrls where
  "/" as root { get => rootHandler }
  "/items" {
    "/:id:Nat" as item {
      get => itemGetHandler
      put => itemPutHandler
    }
    "/special" as special { get => specialHandler }
  }

#guard urls.root = "/"
#guard urls.item 7 = "/items/7"
#guard urls.special = "/items/special"

#guard dispatchTable (routes 0) .get [] = some "root"
#guard dispatchTable (routes 0) .get ["items", "7"] = some "get-item-7"
#guard dispatchTable (routes 0) .put ["items", "7"] = some "put-item-7"
-- The literal `/items/special` must win over the capture `/items/:id:Nat` for the same method --
-- confirms the macro's flattened list preserves the disambiguation the hand-written table relied
-- on (plan doc §5), not just that each route works when dispatched in isolation.
#guard dispatchTable (routes 0) .get ["items", "special"] = some "special"
#guard dispatchTable (routes 0) .delete ["items", "7"] = none

end PositiveTest

-- A wrong-arity handler is rejected with the same quality of `HandlerType`-mismatch error a
-- hand-written `Route.put "..." handler` call would give (`Handler.lean`'s `badArity` regression,
-- mirrored here through the macro instead of a direct call).
namespace BadArityTest

/--
error: Application type mismatch: The argument
  badArityHandler urls db
has type
  Nat → String → String
but is expected to have type
  HandlerType ((parsePattern "/items/:id:Nat").getD []) String
in the application
  Routing.buildRoute✝ Std.Http.Method.put "/items/:id:Nat" (badArityHandler urls db)
-/
#guard_msgs in
routes! (db : Nat) : TestUrls where
  "/" as root { get => rootHandler }
  "/items/:id:Nat" as item { put => badArityHandler }
  "/items/special" as special { get => specialHandler }

end BadArityTest

-- Malformed fragment text is a macro-time error, never `parsePattern!`'s silent root-pattern
-- fallback (module docstring, plan doc §5).
namespace MalformedPatternTest

/--
error: routes!: malformed route pattern fragment "items/:id:Nat" -- expected a leading '/', no doubled/trailing '/', and every capture written as ':name:Nat' or ':name:String'
-/
#guard_msgs in
routes! (db : Nat) : TestUrls where
  "/" as root { get => rootHandler }
  "items/:id:Nat" as item { get => itemGetHandler }
  "/items/special" as special { get => specialHandler }

end MalformedPatternTest

-- Two nodes with the same `as` name anywhere in the tree (not just siblings) is a macro-time
-- error, not a worse-quality redeclaration failure.
namespace DuplicateNameTest

/--
error: routes!: duplicate route name 'item' (already used for /items/:id:Nat) -- every 'as' name must be unique across the whole tree
-/
#guard_msgs in
routes! (db : Nat) : TestUrls where
  "/" as root { get => rootHandler }
  "/items/:id:Nat" as item { get => itemGetHandler }
  "/items/other/:id:Nat" as item { get => itemGetHandler }

end DuplicateNameTest

-- Two different `as` names resolving to the same full pattern is rejected too -- comparing
-- resolved `List PathSeg`, not local text, since different local fragments under different
-- parents could coincidentally resolve to the same full path.
namespace DuplicatePatternTest

/--
error: routes!: 'as itemAgain' resolves to the same pattern (/items/:id:Nat) as 'as item' -- two names for one pattern defeats the point of naming it
-/
#guard_msgs in
routes! (db : Nat) : TestUrls where
  "/" as root { get => rootHandler }
  "/items/:id:Nat" as item { get => itemGetHandler }
  "/items" { "/:id:Nat" as itemAgain { put => itemPutHandler } }

end DuplicatePatternTest

end Routing
