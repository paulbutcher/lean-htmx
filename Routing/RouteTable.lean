import Lean
import Routing.Handler

/-!
`routeTable! App [ "pattern" as name, ... ]`: generates, for each row, a `String` pattern constant
(`App.namePattern`), a field of a generated `App.Links` structure (`Routing.LinkType` of the parsed
pattern -- `Handler.lean`), and the corresponding field of `App.links` (built with
`Routing.linkFor`). This is exactly `Todo/Links.lean`'s hand-written shape from the routing design
plan's reverse-routing spike, automated.

Deliberately verb-less: a link name denotes a URL, not an HTTP method, so a name is declared once
here regardless of how many methods a route table (`Main.lean`'s hand-written `routes`, unchanged
by this macro) later dispatches to that same pattern.
-/

namespace Routing

open Lean Lean.Elab Lean.Elab.Command

declare_syntax_cat routeTableRow
syntax str "as" ident : routeTableRow

/-- The bracketed, comma-separated row list, factored out into its own named parser (rather than
inlined into `routeTableCmd` below) because the `,*,?` sepBy-with-optional-trailing-comma sugar
only elaborates inside a `syntax name := ...` alias, matching the same shape core uses for e.g.
`rwRuleSeq` (`Init/Tactics.lean`). -/
syntax routeTableRows := "[" withoutPosition(routeTableRow,*,?) "]"

/-- See the module docstring. `App` names the generated `App.Links`/`App.links`/`App.<name>Pattern`
declarations. -/
syntax (name := routeTableCmd) "routeTable!" ident routeTableRows : command

/-- Appends `suffix` to `appName`'s ident to build a qualified name like `Todo.indexPattern`,
positioned at `src` (the row's own syntax, for error messages pointing at the right place). -/
private def qualify (src : Syntax) (appName : Name) (base : Name) (suffix : String := "") : Ident :=
  mkIdentFrom src (appName ++ Name.mkSimple (base.toString ++ suffix))

private def qualifyPlain (src : Syntax) (appName : Name) (suffix : Name) : Ident :=
  mkIdentFrom src (appName ++ suffix)

/-- Parses `src` as a `command` and elaborates it, blaming `ref` (the `routeTable!` invocation) on
a parse failure. See the "4/5" comment below for why generated commands go through source text
rather than `Syntax` quotation here. -/
private def elabCommandFromSource (ref : Syntax) (src : String) : CommandElabM Unit := do
  match Lean.Parser.runParserCategory (← getEnv) `command src with
  | .error msg => throwErrorAt ref msg
  | .ok stx => elabCommand stx

/-- Lean *source text* for one already-parsed `PathSeg`, e.g. `.lit "todos"` renders as
`Routing.PathSeg.lit "todos"`. Used (below) to splice an already-parsed, already-in-normal-form
`List PathSeg` *literal* into generated code, rather than a `Routing.parsePattern! "pattern"` call
the elaborator would still have to reduce. -/
private def segSrc : PathSeg → String
  | .lit s => s!"Routing.PathSeg.lit {s.quote}"
  | .capture name .nat => s!"Routing.PathSeg.capture {name.quote} .nat"
  | .capture name .string => s!"Routing.PathSeg.capture {name.quote} .string"

/-- Parses `pat`'s string value with the real `Routing.parsePattern` (so this can never drift from
what `Main.lean`'s dispatch table itself accepts), then renders the result back to Lean source
text for a `List PathSeg` literal. `throwErrorAt pat` on a malformed pattern -- deliberately not
`parsePattern!`, whose silent `getD []` fallback (`Pattern.lean`) is fine for a pattern trusted to
already be well-formed, but not for one a macro is about to bake into a generated declaration. -/
private def segsSrcFor (pat : TSyntax `str) : CommandElabM String := do
  match parsePattern pat.getString with
  | some segs => pure <| "[" ++ String.intercalate ", " (segs.map segSrc) ++ "]"
  | none => throwErrorAt pat s!"invalid route pattern {pat.getString.quote}"

elab_rules : command
  | `(routeTable! $appId:ident [ $rows,* ]) => do
    let appName := appId.getId
    -- 1. Destructure each row into (pattern string literal, name).
    let entries ← rows.getElems.mapM fun row => do
      match row with
      | `(routeTableRow| $pat:str as $name:ident) => pure (pat, name)
      | _ => throwUnsupportedSyntax

    -- 2. Reject a name declared twice -- each name denotes exactly one pattern.
    let mut seen : Std.HashMap Name Syntax := {}
    for (_, name) in entries do
      if let some prior := seen[name.getId]? then
        throwErrorAt name s!"route name '{name.getId}' already declared at {prior}"
      seen := seen.insert name.getId name

    -- 3. One `def App.namePattern : String := "pattern"` per row.
    for (pat, name) in entries do
      let patIdent := qualify name appName name.getId "Pattern"
      elabCommand (← `(def $patIdent : String := $pat))

    -- 4/5. `structure App.Links where name : LinkType [PathSeg literal] ...` and
    -- `def App.links : App.Links := { name := linkFor [PathSeg literal], ... }`.
    --
    -- Two things worth flagging:
    --
    -- * Built as source text and reparsed (`elabCommandFromSource` above) rather than spliced via
    --   `$[...]*` quotation antiquotations: `structure`'s field list (`structFields`, `Parser/
    --   Command.lean`) is a `manyIndent`, which -- unlike the plain `sepBy` behind `$xs,*`
    --   splicing -- depends on real column/indentation tracking that synthetic, macro-built
    --   `Syntax` doesn't carry, so the antiquotation form silently parses as a zero-field
    --   structure. Confirmed by a throwaway spike (`lean_diagnostic_messages` against exactly
    --   this quotation) before falling back to this approach, matching `docs/routing-design-
    --   plan.md`'s own spike-first methodology.
    -- * Fields are typed by an already-parsed `List PathSeg` *literal* (`segsSrcFor`), not a
    --   `Routing.parsePattern! "pattern"` call for the elaborator to reduce: a zero-capture field
    --   (`toggleAll`, `clearCompleted`, ...) has no argument application to force that reduction,
    --   so real usage (`Todo/Views.lean`'s `hxPost := links.toggleAll` against an `Option String`
    --   field, via the `Coe String (Option String)` instance) failed to typecheck against the
    --   `parsePattern!`-call form -- caught by building `Todo/Links.lean` against this macro for
    --   real (`docs/todo-app-plan.md`'s own "verify end-to-end, not just typechecked" standard),
    --   not by this file's own `#guard`s in isolation.
    let linksTypeIdent := qualifyPlain appId appName `Links
    let linksValIdent := qualifyPlain appId appName `links
    let structFieldsSrc := String.intercalate "\n  " <|
      ← entries.toList.mapM fun (pat, name) => do
        pure s!"{name.getId} : Routing.LinkType {← segsSrcFor pat}"
    elabCommandFromSource appId
      s!"structure {linksTypeIdent.getId} where\n  {structFieldsSrc}"

    let valFieldsSrc := String.intercalate ", " <|
      ← entries.toList.mapM fun (pat, name) => do
        pure s!"{name.getId} := Routing.linkFor {← segsSrcFor pat}"
    elabCommandFromSource appId <|
      "def " ++ toString linksValIdent.getId ++ " : " ++ toString linksTypeIdent.getId ++
        " := { " ++ valFieldsSrc ++ " }"

routeTable! RouteTableTest
  [ "/" as index,
    "/active" as active,
    "/todos/:id:Nat/edit" as edit ]

-- #guard tests: the pattern constants, the generated structure's shape, and its values -- same
-- shape `Todo/Links.lean` proved by hand before this macro automated it.
#guard RouteTableTest.indexPattern = "/"
#guard RouteTableTest.activePattern = "/active"
#guard RouteTableTest.editPattern = "/todos/:id:Nat/edit"
#guard RouteTableTest.links.index = "/"
#guard RouteTableTest.links.active = "/active"
#guard RouteTableTest.links.edit 7 = "/todos/7/edit"

-- Negative-compile regression: declaring the same name twice is a command-time error, not a
-- silently-overwritten field.
/--
error: route name 'index' already declared at `index
-/
#guard_msgs in
routeTable! RouteTableTestDup
  [ "/" as index,
    "/elsewhere" as index ]

end Routing
