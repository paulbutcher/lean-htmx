import Lean
import Routing.Route
import Routing.Url
import Routing.Server

/-!
`application`: a route-tree command macro that reads as a nested route tree (pattern nesting
shared, methods and handlers inline) and produces one `Application` value bundling the dispatch
handler with a generated reverse-routing `Urls` struct. See `docs/application-macro-plan.md` for
the full design rationale -- this is the implementation.

## Grammar

```
application app : SQLite where
  "/" as index { get => pageHandler .all }
  "/todos" as todos {
    post => addHandler
    "/:id:Nat" as todo {
      put => saveHandler
      delete => deleteHandler
    }
  }
```

A `routeItem` is either a `method => handler` entry or a `"pattern" (as name)? { item* }` fragment,
recursing into itself -- one syntax category, two productions, ported unchanged from the reverted
`routes!` spike (`git show a8a3cdc^:Routing/RoutesMacro.lean`). A node's *resolved* pattern is its
parent's resolved segments `++` its own local segments (`List PathSeg` append, not string
concatenation).

## What it expands to

Two declarations, spliced into the file the `application` invocation is written in:

- `structure <Name>Urls where ...` -- one field per `as`-named node anywhere in the tree, field
  type computed directly from that node's resolved `List PathSeg` (`Nat → String`, not
  `UrlType (parsePattern! ...)` -- see `fieldTypeText` below and
  `docs/application-macro-plan.md` §5 for why the concrete arrow type is emitted as text rather
  than a quoted term).
- `def <name> : Application <CtxType> <Name>Urls := let urls := { ... }; { urls, handler := fun
  ctx => toHandler [ ... ] }` -- every route handler applied to `ctx urls` (that order) before its
  captures, matching today's handlers' existing `db`-first convention.

`<Name>Urls` is derived from the binder (`app` → `AppUrls`), not a fixed literal -- lets two
`application` blocks coexist in one namespace without colliding.

## Structure declarations aren't quotable with a dynamic field list

Ordinary term-level quotation antiquotation (`Term.structInst`, `{ f := v, ... }`) already splices
a dynamic list fine (confirmed directly, and by the reverted spike's `def urls := { ... }`). But
`structure ... where`'s field list (`structFields`/`structSimpleBinder`,
`Lean/Parser/Command.lean`) is *not* a registered syntax category -- `` `(command| structure Foo
where $[$names : $tys]*) `` fails to parse ("unexpected token '$'; expected ')'"), confirmed
directly rather than assumed. Sidestepped by building the whole `structure` command as source text
(field types as concrete arrow-type text, e.g. `"Nat → String"`) and parsing it with
`Lean.Parser.runParserCategory`, then `elabCommand`ing the result the same way a quotation-built
`Syntax` would be -- this is also what lets field types be emitted as concrete arrow types directly
rather than `UrlType (parsePattern! ...)` (`docs/application-macro-plan.md` §5's instance-search
transparency concern).

## Non-hygienic names, deliberately

`urls` (the local reverse-routing bundle), `ctx` (the handler-closure's context parameter), and
`<Name>Urls` (the generated structure) are all built with `mkIdent`, not literal text in a
quotation -- a literal identifier written directly in `` `(...) `` is hygienically mangled per
quotation call and invisible to a *different* quotation call/call site, but `mkIdent` produces a
plain, unscoped name that resolves consistently everywhere it's spliced, exactly like ordinary
hand-written source. This is load-bearing here specifically because `urls`/`ctx` are referenced
across several independently-built `TSyntax` fragments (one per route entry) that all get spliced
into one final `def`.
-/

namespace Routing

open Lean Elab Command Meta
open Std Http Server

/-- Bundles a route table's dispatch handler (still curried over the app's context type) with a
generated reverse-routing `Urls` struct, produced together by `application` above. -/
structure Application (Ctx Urls : Type) where
  urls    : Urls
  handler : Ctx → StatelessHandler

/-- One node in an `application` tree: either a `method => handler` entry, or a further
`"pattern" (as name)? { ... }` fragment. Ported unchanged from the reverted `routes!` spike. -/
declare_syntax_cat routeItem

/-- `get => handler`, `post => handler`, `put => handler`, `delete => handler`. -/
syntax ident " => " term : routeItem

/-- `"pattern" (as name)? { item* }`. `manyIndent`, not a bare `routeItem*`: without it, a handler
`term` with nothing to stop it greedily continues parsing across a newline as a further
application argument, mis-parsing the next sibling fragment as an extra argument to the previous
handler (confirmed by the reverted spike). -/
syntax str (" as " ident)? " { " manyIndent(routeItem) " } " : routeItem

/-- `application <name> : <CtxType> (deriving <ClassName>)? where <items>`. The optional `deriving`
clause names a typeclass (e.g. `Todo.HasUrls`) that a caller upstream of this file declared for its
own reasons (`docs/application-macro-plan.md`'s Phase 3 circular-import problem: a library upstream
of the file `application` is invoked in can't reference the struct this macro is about to generate,
so it depends on an abstract `{Urls} [ClassName Urls]` instead) -- the macro emits a mechanical
instance (field name ↦ same-named method) between its two generated declarations, the one place
that gap can actually be closed, since only the macro's own generated code runs there. -/
syntax "application " ident " : " term (" deriving " ident)? " where " manyIndent(routeItem) :
  command

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
and every `as`-named node (ditto) found anywhere in it. Each fragment's local pattern text is
parsed with `parsePattern` (never `parsePattern!`) -- a `none` result is a macro-time
`throwErrorAt` pointing at that fragment's own string literal, never `parsePattern!`'s silent
root-pattern fallback. -/
private partial def processItems (parentSegs : List PathSeg) (items : Array (TSyntax `routeItem)) :
    CommandElabM (Array MethodEntry × Array NamedNode) := do
  let mut methodEntries : Array MethodEntry := #[]
  let mut namedNodes : Array NamedNode := #[]
  for item in items do
    match item with
    | `(routeItem| $m:ident => $h:term) =>
      if !isKnownMethod m.getId.toString then
        throwErrorAt m
          s!"application: unknown HTTP method '{m.getId}' -- expected one of get, post, put, delete"
      methodEntries := methodEntries.push { method := m, handler := h, segs := parentSegs }
    | `(routeItem| $s:str $[as $n:ident]? { $subItems* }) =>
      let localStr := s.getString
      let localSegs ←
        match parsePattern localStr with
        | some segs => pure segs
        | none =>
          throwErrorAt s
            s!"application: malformed route pattern fragment {localStr.quote} -- expected a \
              leading '/', no doubled/trailing '/', and every capture written as ':name:Nat' or \
              ':name:String'"
      let resolvedSegs := parentSegs ++ localSegs
      if let some name := n then
        namedNodes := namedNodes.push { name := name, segs := resolvedSegs }
      let (subMethods, subNamed) ← processItems resolvedSegs subItems
      methodEntries := methodEntries ++ subMethods
      namedNodes := namedNodes ++ subNamed
    | _ => throwErrorAt item "application: unrecognized item"
  return (methodEntries, namedNodes)

/-- Erases capture names from a resolved `List PathSeg`, leaving only the shape (`.lit`/`.capture
_ kind`) that `HandlerType`/`dispatch` and `UrlType`/`renderUrl` actually match on -- capture names
are documentation-only downstream (`docs/application-macro-plan.md` §5). Used so the
duplicate-pattern check treats `/items/:id:Nat` and `/items/:pk:Nat` as the same route, which raw
`List PathSeg` equality (the reverted spike's check) would miss. -/
private def eraseNames (segs : List PathSeg) : List PathSeg :=
  segs.map fun
    | .lit s => .lit s
    | .capture _ kind => .capture "" kind

/-- Rejects two structural problems across the *whole* tree (not just siblings): two nodes sharing
an `as` name, and two different `as` names resolving to the same full pattern -- compared as a
name-erased *shape* (`eraseNames`), not raw `List PathSeg`, so `/items/:id:Nat` as `item` and
`/items/:pk:Nat` as `itemAgain` are correctly flagged as the same route despite differing capture
variable names. Both are macro-time errors pointing at the second (later) offending node. -/
private def checkNamedNodes (namedNodes : Array NamedNode) : CommandElabM Unit := do
  let mut seenNames : Std.HashMap String (List PathSeg) := {}
  let mut seenShapes : Array (List PathSeg × TSyntax `ident) := #[]
  for n in namedNodes do
    let nm := n.name.getId.toString
    if let some earlierSegs := seenNames[nm]? then
      throwErrorAt n.name
        s!"application: duplicate route name '{nm}' (already used for {renderPattern earlierSegs}) \
          -- every 'as' name must be unique across the whole tree"
    seenNames := seenNames.insert nm n.segs
    let shape := eraseNames n.segs
    if let some (_, earlierName) := seenShapes.find? (fun (s, _) => s == shape) then
      throwErrorAt n.name
        s!"application: 'as {nm}' resolves to the same pattern ({renderPattern n.segs}) as \
          'as {earlierName.getId}' -- two names for one pattern defeats the point of naming it"
    seenShapes := seenShapes.push (shape, n.name)

/-- Field-type text (`docs/application-macro-plan.md` §5): folds a resolved `List PathSeg` into
its reverse-routing field's arrow-type *text* directly (`"Nat → String"`, not
`"UrlType (parsePattern! ...)"`) -- avoids the instance-search transparency risk
`docs/routing-design-plan.md` §4 found for computed types (confirmed unnecessary to work around
further here: a struct field emitted this way is usable in ordinary `#guard` equality checks with
no instance-search friction, see the tests below). -/
private def fieldTypeText : List PathSeg → String
  | [] => "String"
  | .lit _ :: rest => fieldTypeText rest
  | .capture _ .nat :: rest => s!"Nat → {fieldTypeText rest}"
  | .capture _ .string :: rest => s!"String → {fieldTypeText rest}"

/-- `app` → `` `AppUrls ``: capitalizes the binder's first character and appends `Urls`. Deriving
from the user's chosen name (rather than a fixed literal, as the reverted spike used) is what lets
two `application` blocks coexist in one namespace. -/
private def deriveUrlsName (appName : Name) : Name :=
  let s := appName.toString
  Name.mkSimple <|
    match s.toList with
    | [] => "Urls"
    | c :: cs => String.ofList (c.toUpper :: cs) ++ "Urls"

/-- Parses `source` against the `command` category and `elabCommand`s the result -- the escape
hatch for splicing a `structure` declaration's dynamic field list (module docstring). -/
private def elabCommandFromString (source : String) : CommandElabM Unit := do
  let env ← getEnv
  match Parser.runParserCategory env `command source with
  | .ok stx => elabCommand stx
  | .error err => throwError err

elab_rules : command
  | `(application $name:ident : $ctxTy $[deriving $derivingClass:ident]? where $items*) => do
    let (methodEntries, namedNodes) ← processItems [] items
    checkNamedNodes namedNodes
    let urlsTypeIdent := mkIdent (deriveUrlsName name.getId)
    let structureSource :=
      if namedNodes.isEmpty then
        s!"structure {urlsTypeIdent.getId} where"
      else
        let fieldLines := namedNodes.toList.map fun n =>
          s!"  {n.name.getId} : {fieldTypeText n.segs}"
        s!"structure {urlsTypeIdent.getId} where\n" ++ String.intercalate "\n" fieldLines
    elabCommandFromString structureSource
    -- `deriving <ClassName>`: emitted here, between the struct and the def, the one place a
    -- typeclass instance for the freshly-generated struct can be inserted within this one atomic
    -- invocation (module docstring / `docs/application-macro-plan.md`). Mechanical -- field name
    -- ↦ same-named method, `fun u => u.field` -- so it doesn't need to know anything about
    -- `derivingClass` beyond its name; a mismatched method name surfaces as an ordinary "missing
    -- field"/"unknown identifier" elaboration error from the instance itself.
    if let some cls := derivingClass then
      let instanceSource :=
        if namedNodes.isEmpty then
          s!"instance : {cls.getId} {urlsTypeIdent.getId} where"
        else
          let fieldLines := namedNodes.toList.map fun n =>
            s!"  {n.name.getId} := fun u => u.{n.name.getId}"
          s!"instance : {cls.getId} {urlsTypeIdent.getId} where\n" ++ String.intercalate "\n" fieldLines
      elabCommandFromString instanceSource
    let ctxIdent := mkIdent `ctx
    let urlsIdent := mkIdent `urls
    let urlsFields ← namedNodes.mapM fun n => do
      let patLit := Syntax.mkStrLit (renderPattern n.segs)
      `(routeUrl $patLit)
    let urlsNames := namedNodes.map (·.name)
    let routeElems ← methodEntries.mapM fun e => do
      let patLit := Syntax.mkStrLit (renderPattern e.segs)
      let handlerApplied ← `($(e.handler) $ctxIdent $urlsIdent)
      -- `Route.get`/`.post`/`.put`/`.delete` are literal-only macros (`Routing/Route.lean`), not
      -- plain `def`s -- reached only via their own quotation form here. `isKnownMethod` was
      -- already checked true for every entry in `processItems`.
      match e.method.getId.toString with
      | "get" => `(Route.get $patLit $handlerApplied)
      | "post" => `(Route.post $patLit $handlerApplied)
      | "put" => `(Route.put $patLit $handlerApplied)
      | "delete" => `(Route.delete $patLit $handlerApplied)
      | m => throwErrorAt e.method s!"application: unknown HTTP method '{m}'"
    let appDef ← `(command|
      def $name : Application $ctxTy $urlsTypeIdent :=
        let $urlsIdent:ident : $urlsTypeIdent := { $[$urlsNames:ident := $urlsFields],* }
        { urls := $urlsIdent, handler := fun ($ctxIdent : $ctxTy) => toHandler [ $routeElems,* ] })
    elabCommand appDef

/-! ## Tests

`Routing` stays app-framework-agnostic (`Routing.lean`'s module docstring) -- it can't depend on
`Todo`/`SQLite`, so these use a toy `Nat` standing in for a context, mirroring the shape a real
consumer supplies without actually depending on one.

`Application.handler` is fixed at `Ctx → StatelessHandler` (§2), not generic over a toy `result`
type the way the reverted spike's `Route result`/`dispatchTable` tests were -- so exercising the
macro's *actual* flattened output here means running real `Request`/`Response` values through it,
not just comparing a `String` return value. `Std.Http.Test.Helpers` (part of the toolchain, used by
`Std.Http`'s own server tests) gives exactly that: a mock connection, request-string builders
(`mkGet`/`mkPost`), and response assertions (`assertContains`) -- reused here rather than
hand-rolling `Body.Stream`/`ContextAsync` plumbing. -/

open Std.Http.Internal.Test
open Std.Async

private def rootHandler {Urls : Type} (_ctx : Nat) (_urls : Urls) (_req : Request Body.Stream) :
    ContextAsync (Response Body.Any) :=
  Response.ok |>.text "root"

private def itemGetHandler {Urls : Type} (_ctx : Nat) (_urls : Urls) (id : Nat)
    (_req : Request Body.Stream) : ContextAsync (Response Body.Any) :=
  Response.ok |>.text s!"get-item-{id}"

private def itemPutHandler {Urls : Type} (_ctx : Nat) (_urls : Urls) (id : Nat)
    (_req : Request Body.Stream) : ContextAsync (Response Body.Any) :=
  Response.ok |>.text s!"put-item-{id}"

private def specialHandler {Urls : Type} (_ctx : Nat) (_urls : Urls)
    (_req : Request Body.Stream) : ContextAsync (Response Body.Any) :=
  Response.ok |>.text "special"

private def badArityHandler {Urls : Type} (_ctx : Nat) (_urls : Urls) (_id : Nat) (_extra : String)
    (_req : Request Body.Stream) : ContextAsync (Response Body.Any) :=
  Response.ok |>.text "oops"

/-- `mkGet`/`mkPost` are provided by `Std.Http.Test.Helpers`; `PUT`/`DELETE` aren't, so build them
the same way. -/
private def mkPut (path : String) : String :=
  s!"PUT {path} HTTP/1.1\x0d\nHost: example.com\x0d\nContent-Length: 0\x0d\n\x0d\n"

private def mkDelete (path : String) : String :=
  s!"DELETE {path} HTTP/1.1\x0d\nHost: example.com\x0d\nContent-Length: 0\x0d\n\x0d\n"

-- Main positive regression: 2-3 levels of nesting, a captured node with two methods sharing one
-- written pattern (`PUT`/`GET` on `/items/:id:Nat`), a same-arity literal/capture collision
-- (`/items/special` vs `/items/:id:Nat`) exercised through the macro's *actual* flattened dispatch
-- output, and (new, not in the reverted spike) an `as`-named node with a method entry directly on
-- it *and* nested child fragments (`/todos` below) -- the shape the real Todo migration (Phase 3)
-- depends on.
namespace PositiveTest

application testApp : Nat where
  "/" as root { get => rootHandler }
  "/items" {
    "/:id:Nat" as item {
      get => itemGetHandler
      put => itemPutHandler
    }
    "/special" as special { get => specialHandler }
  }
  "/todos" as todos {
    post => rootHandler
    "/:id:Nat" as todo { get => itemGetHandler }
  }

#guard testApp.urls.root = "/"
#guard testApp.urls.item 7 = "/items/7"
#guard testApp.urls.special = "/items/special"
#guard testApp.urls.todos = "/todos"
#guard testApp.urls.todo 3 = "/todos/3"

private def testHandler : TestHandler := (testApp.handler 0).onRequest

#eval runGroup "PositiveTest" do
  checkClose "root" (mkGet "/") testHandler (assertContains · "root")
  checkClose "item get" (mkGet "/items/7") testHandler (assertContains · "get-item-7")
  checkClose "item put" (mkPut "/items/7") testHandler (assertContains · "put-item-7")
  -- The literal `/items/special` must win over the capture `/items/:id:Nat` for the same method.
  checkClose "special beats capture" (mkGet "/items/special") testHandler (assertContains · "special")
  checkClose "todos: method on a named node with children" (mkPost "/todos" "") testHandler
    (assertContains · "root")
  checkClose "todos: nested child nested under it" (mkGet "/todos/3") testHandler
    (assertContains · "get-item-3")
  checkClose "unmatched route falls through to 404" (mkGet "/nope") testHandler
    (fun r => assertStatus r "HTTP/1.1 404")

end PositiveTest

-- A wrong-arity handler is rejected with the same quality of `HandlerType`-mismatch error a
-- hand-written `Route.put "..." handler` call would give.
namespace BadArityTest

/--
error: Application type mismatch: The argument
  badArityHandler ctx urls
has type
  Nat → String → Request Body.Stream → ContextAsync (Response Body.Any)
but is expected to have type
  HandlerType (parsePattern! "/items/:id:Nat") Result
in the application
  Route.put "/items/:id:Nat" (badArityHandler ctx urls)
-/
#guard_msgs in
application badArityApp : Nat where
  "/" as root { get => rootHandler }
  "/items/:id:Nat" as item { put => badArityHandler }
  "/items/special" as special { get => specialHandler }

end BadArityTest

-- Malformed fragment text is a macro-time error, never `parsePattern!`'s silent root-pattern
-- fallback.
namespace MalformedPatternTest

/--
error: application: malformed route pattern fragment "items/:id:Nat" -- expected a leading '/', no doubled/trailing '/', and every capture written as ':name:Nat' or ':name:String'
-/
#guard_msgs in
application malformedApp : Nat where
  "/" as root { get => rootHandler }
  "items/:id:Nat" as item { get => itemGetHandler }
  "/items/special" as special { get => specialHandler }

end MalformedPatternTest

-- Two nodes with the same `as` name anywhere in the tree (not just siblings) is a macro-time
-- error, not a worse-quality redeclaration failure.
namespace DuplicateNameTest

/--
error: application: duplicate route name 'item' (already used for /items/:id:Nat) -- every 'as' name must be unique across the whole tree
-/
#guard_msgs in
application duplicateNameApp : Nat where
  "/" as root { get => rootHandler }
  "/items/:id:Nat" as item { get => itemGetHandler }
  "/items/other/:id:Nat" as item { get => itemGetHandler }

end DuplicateNameTest

-- Two different `as` names resolving to the same full pattern (same literal/capture-kind shape)
-- is rejected too.
namespace DuplicatePatternTest

/--
error: application: 'as itemAgain' resolves to the same pattern (/items/:id:Nat) as 'as item' -- two names for one pattern defeats the point of naming it
-/
#guard_msgs in
application duplicatePatternApp : Nat where
  "/" as root { get => rootHandler }
  "/items/:id:Nat" as item { get => itemGetHandler }
  "/items" { "/:id:Nat" as itemAgain { put => itemPutHandler } }

end DuplicatePatternTest

-- Two names resolving to the same shape via *different* capture variable names -- the
-- name-erasure fix (module docstring / `docs/application-macro-plan.md` §5), confirming what raw
-- `List PathSeg` equality (the reverted spike's check) would miss.
namespace DuplicatePatternCaptureNameTest

/--
error: application: 'as itemAgain' resolves to the same pattern (/items/:pk:Nat) as 'as item' -- two names for one pattern defeats the point of naming it
-/
#guard_msgs in
application duplicateCaptureApp : Nat where
  "/" as root { get => rootHandler }
  "/items/:id:Nat" as item { get => itemGetHandler }
  "/items/:pk:Nat" as itemAgain { get => itemGetHandler }

end DuplicatePatternCaptureNameTest

-- Edge case: zero `as`-named nodes anywhere -- the generated `structure` has no fields, and the
-- empty anonymous-constructor splice `{ }` must still elaborate.
namespace EmptyUrlsTest

application emptyUrlsApp : Nat where
  "/" { get => rootHandler }
  "/items/:id:Nat" { get => itemGetHandler }

#eval runGroup "EmptyUrlsTest" do
  checkClose "root" (mkGet "/") (emptyUrlsApp.handler 0).onRequest (assertContains · "root")

end EmptyUrlsTest

-- Edge case: zero method entries anywhere -- the generated `toHandler [...]` list is empty, and
-- every request falls through to `notFound`.
namespace EmptyMethodsTest

application emptyMethodsApp : Nat where
  "/" as root { }

#guard emptyMethodsApp.urls.root = "/"

#eval runGroup "EmptyMethodsTest" do
  checkClose "no routes, always 404" (mkGet "/") (emptyMethodsApp.handler 0).onRequest
    (fun r => assertStatus r "HTTP/1.1 404")

end EmptyMethodsTest

-- `deriving <ClassName>`: the mechanical instance the macro emits between its two generated
-- declarations must make the struct usable through the class's methods, not just through direct
-- field projection.
private class ToyHasUrls (Urls : Type) where
  root : Urls → String
  item : Urls → Nat → String

namespace DerivingTest

application derivingApp : Nat deriving ToyHasUrls where
  "/" as root { get => rootHandler }
  "/items/:id:Nat" as item { get => itemGetHandler }

#guard derivingApp.urls.root = "/"
#guard ToyHasUrls.root derivingApp.urls = "/"
#guard ToyHasUrls.item derivingApp.urls 7 = "/items/7"

end DerivingTest

-- Two `application` blocks in the *same* namespace, each generating its own `<Name>Urls`
-- struct/def -- the direct check of deriving generated names from the binder (rather than a fixed
-- `urls`/`routes` literal) removing the multi-block collision the reverted spike needed per-test
-- `namespace` isolation to avoid.
namespace TwoBlocksTest

application app1 : Nat where
  "/" as root { get => rootHandler }

application app2 : Nat where
  "/" as root { get => rootHandler }

#guard app1.urls.root = "/"
#guard app2.urls.root = "/"

end TwoBlocksTest

end Routing
