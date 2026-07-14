import Lean
import Std.Http.Data.Method
import Routing.Handler

/-!
Bundling a method, a path pattern, and a matching handler into a `Route`,
and dispatching an incoming `(Method, path)` against a table of them in
order. Method dispatch is ordinary pattern matching against
`Std.Http.Method` (a plain closed inductive, `Std/Http/Data/Method.lean`)
-- no type-safety question there, per `docs/routing-design-plan.md` §5.

## `Route.get`/`.post`/`.put`/`.delete` are literal-only macros, not plain `def`s

`docs/reverse-routing-macro-tasks.md` §2.4: `parsePattern!` (formerly used here) silently defaulted
a malformed pattern to the *root* pattern `[]` instead of panicking or erroring, despite its old
docstring's claim otherwise (`Pattern.lean`, Phase 0). The actual fix -- confirmed by a throwaway
spike, not assumed -- is elaboration-time literal checking: `Route.get`/`.post`/`.put`/`.delete`
are `macro`s requiring their pattern argument to be a string *literal* (`str`, not an arbitrary
`String` expression), parsed via `parsePattern` at macro-expansion time, with `none` rejected via
`Macro.throwErrorAt` pointing at the literal itself.

Two things the spike found that don't survive contact with dot notation:

- **Dot notation (`.get "..." handler`) resolves only against a real declaration, never through
  the macro table.** Confirmed directly: a `Foo.mk2` implemented purely as `syntax`/`macro_rules`
  (no coexisting `def Foo.mk2`) makes `.mk2 args` fail with "Unknown constant `Foo.mk2`" -- Lean's
  generalized field/dot notation resolves an identifier by looking up an actual `Name` in the
  environment and elaborating its application directly, never by re-parsing/re-dispatching through
  `Syntax`-level `macro_rules`. A macro and a same-named `def` can't both back dot notation for one
  name; picking the macro (for the hardening this file exists to add) means dot notation to these
  four names no longer resolves. The only call site that used to rely on it was this file's own
  `testRoutes` below, now written with the qualified names instead -- confirmed to be the only one
  by grepping the whole project (`docs/reverse-routing-macro-tasks.md` §2.4's own precondition).
- **A dotted keyword atom (e.g. `"Route.get"`) is valid `syntax` atom text** -- the earlier
  "invalid atom" failure during the spike turned out to be from an *embedded trailing space*
  inside the atom string, not the `.`; confirmed by isolating the two down to separate repros.
- **The generic 3-argument `route` (method, pattern, handler) is not hardened the same way and no
  longer has a public name at all.** A leading `method : Method` argument written as arbitrary
  `term` syntax immediately followed by the pattern `str` token hits the same greedy-application
  parsing hazard `Routing/RoutesMacro.lean`'s module docstring describes for multi-line fragment
  lists, except here even on one line: `route .get "/x" h` risks parsing `.get "/x"` as `.get`
  applied to the string literal before the macro's own `str`/`term` pieces ever get a chance to
  match. Since nothing outside this file ever called `route` directly (confirmed by the same grep
  above), it's folded directly into `buildRoute` below instead of also being hardened as a macro.
-/

namespace Routing

open Std.Http (Method)
open Lean

/-- One route: an HTTP method, a path pattern (as already-parsed segments,
so `HandlerType segs result` -- and therefore `handler`'s arity/types --
is checked at the point the route is built), and its handler. -/
structure Route (result : Type) where
  method : Method
  segs : List PathSeg
  handler : HandlerType segs result

/-- Builds a `Route` from a method, a pattern *string*, and a handler, unconditionally (no literal
requirement, no macro-time validation). Not part of the public API -- only ever called from the
`Route.get`/`.post`/`.put`/`.delete` macros below, immediately after they've already confirmed
(via `parsePattern`, at macro-expansion time) that `pattern` is well-formed, which is what makes
the `.getD []` fallback here dead code in practice rather than a silent-misrouting risk. -/
private def buildRoute (method : Method) (pattern : String) {result : Type}
    (handler : HandlerType ((parsePattern pattern).getD []) result) : Route result :=
  { method, segs := (parsePattern pattern).getD [], handler }

/-- Parses `pat`'s string value via `parsePattern`, expanding to `buildRoute $methodName $pat
$handler` on success or a `Macro.throwErrorAt` pointing at `pat` itself on `none`. Shared by the
four `syntax`/`macro_rules` pairs below so the literal-checking logic is written once. -/
private def expandRouteLiteral (methodName : TSyntax `term) (pat : TSyntax `str)
    (handler : TSyntax `term) : MacroM (TSyntax `term) := do
  let s := pat.getString
  match parsePattern s with
  | some _ => `(buildRoute $methodName $pat $handler)
  | none =>
    Macro.throwErrorAt pat
      s!"routes: malformed route pattern {s.quote} -- expected a leading '/', no doubled/trailing \
        '/', and every capture written as ':name:Nat' or ':name:String'"

/-- Builds a `Route` for a `GET` request against a pattern *literal*. See the module docstring for
why this is a macro (elaboration-time literal validation) rather than a plain `def`, and why it can
no longer be reached via dot notation (`.get "..." handler`) -- use `Route.get "..." handler`. -/
syntax "Route.get" str term : term
macro_rules
  | `(Route.get $pat:str $h) => do expandRouteLiteral (← `(Method.get)) pat h

syntax "Route.post" str term : term
macro_rules
  | `(Route.post $pat:str $h) => do expandRouteLiteral (← `(Method.post)) pat h

syntax "Route.put" str term : term
macro_rules
  | `(Route.put $pat:str $h) => do expandRouteLiteral (← `(Method.put)) pat h

syntax "Route.delete" str term : term
macro_rules
  | `(Route.delete $pat:str $h) => do expandRouteLiteral (← `(Method.delete)) pat h

/-- Matches one route against an incoming method and decoded path,
producing the handler's result applied to any extracted captures. `none`
if the method doesn't match, or if `dispatch` rejects the path (literal
mismatch, mistyped capture, or arity mismatch -- `Handler.lean`). -/
def Route.tryDispatch (r : Route result) (method : Method) (path : List String) :
    Option result :=
  if r.method == method then dispatch r.segs r.handler path else none

/-- Tries each route in order, returning the first match. This is the
"table of routes" half of `docs/routing-design-plan.md` §5's wiring step;
pairing it with `Std.Http.Server.Handler` is `Server.lean`. -/
def dispatchTable (routes : List (Route result)) (method : Method) (path : List String) :
    Option result :=
  routes.findSome? (Route.tryDispatch · method path)

-- #guard tests: first match wins, method mismatch, path mismatch all fall through. Written with
-- qualified names (`Route.get`, not `.get`) -- see the module docstring for why dot notation no
-- longer reaches these.
private def testRoutes : List (Route String) :=
  [ Route.get "/" "home",
    Route.get "/users/:id:Nat" (fun (id : Nat) => s!"user #{id}"),
    Route.post "/users/:id:Nat" (fun (id : Nat) => s!"created #{id}") ]

#guard dispatchTable testRoutes .get [] = some "home"
#guard dispatchTable testRoutes .get ["users", "7"] = some "user #7"
#guard dispatchTable testRoutes .post ["users", "7"] = some "created #7"
#guard dispatchTable testRoutes .get ["users", "nope"] = none
#guard dispatchTable testRoutes .delete ["users", "7"] = none
#guard dispatchTable testRoutes .get ["missing"] = none

-- A malformed literal is a macro-time error, never a silent fall-through to the root pattern --
-- the new guarantee this file didn't have before (`Pattern.lean` only ever tested `parsePattern`
-- in isolation, never this caller-facing promise).
--
-- Takes a dummy `Unit` argument rather than being a bare `Route String` value: a *nullary*
-- top-level `def` whose body fails to elaborate still produces a real declaration (a `sorryAx`
-- stub, so downstream references don't cascade more errors), and Lean's compiled executables
-- eagerly force every such nullary constant at module-init time -- confirmed the hard way, via
-- `lake exe webapp` panicking at startup on `executed 'sorry'` with this as a bare value, despite
-- nothing ever calling it. A one-argument function is never eagerly forced, only called.
/--
error: routes: malformed route pattern "users/:id:Nat" -- expected a leading '/', no doubled/trailing '/', and every capture written as ':name:Nat' or ':name:String'
-/
#guard_msgs in
def badPattern (_ : Unit) : Route String := Route.get "users/:id:Nat" "oops"

end Routing
