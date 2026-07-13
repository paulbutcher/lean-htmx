import Std.Http.Data.Method
import Routing.Handler

/-!
Bundling a method, a path pattern, and a matching handler into a `Route`,
and dispatching an incoming `(Method, path)` against a table of them in
order. Method dispatch is ordinary pattern matching against
`Std.Http.Method` (a plain closed inductive, `Std/Http/Data/Method.lean`)
-- no type-safety question there, per `docs/routing-design-plan.md` §5.
-/

namespace Routing

open Std.Http (Method)

/-- One route: an HTTP method, a path pattern (as already-parsed segments,
so `HandlerType segs result` -- and therefore `handler`'s arity/types --
is checked at the point the route is built), and its handler. -/
structure Route (result : Type) where
  method : Method
  segs : List PathSeg
  handler : HandlerType segs result

/-- Builds a `Route` from a method, a pattern *string*, and a handler.
The pattern is parsed with `parsePattern!`, which panics on a malformed
pattern -- acceptable here because route patterns are source-code literals
written by the route author, so a malformed one is a programming error
that should surface immediately at startup, not something to recover from
at request time (`Pattern.lean`'s `parsePattern!` docstring). -/
def route (method : Method) (pattern : String) {result : Type}
    (handler : HandlerType (parsePattern! pattern) result) : Route result :=
  { method, segs := parsePattern! pattern, handler }

/-- Per-method aliases for `route`, so a route table can write `.get`/`.post`/`.put`/`.delete`
(resolved via Lean's generalized dot notation against the list's expected `Route result` element
type) instead of `route .get`/`route .post`/etc. -/
def Route.get (pattern : String) {result : Type}
    (handler : HandlerType (parsePattern! pattern) result) : Route result :=
  route .get pattern handler

def Route.post (pattern : String) {result : Type}
    (handler : HandlerType (parsePattern! pattern) result) : Route result :=
  route .post pattern handler

def Route.put (pattern : String) {result : Type}
    (handler : HandlerType (parsePattern! pattern) result) : Route result :=
  route .put pattern handler

def Route.delete (pattern : String) {result : Type}
    (handler : HandlerType (parsePattern! pattern) result) : Route result :=
  route .delete pattern handler

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

-- #guard tests: first match wins, method mismatch, path mismatch all fall through.
private def testRoutes : List (Route String) :=
  [ .get "/" "home",
    .get "/users/:id:Nat" (fun (id : Nat) => s!"user #{id}"),
    .post "/users/:id:Nat" (fun (id : Nat) => s!"created #{id}") ]

#guard dispatchTable testRoutes .get [] = some "home"
#guard dispatchTable testRoutes .get ["users", "7"] = some "user #7"
#guard dispatchTable testRoutes .post ["users", "7"] = some "created #7"
#guard dispatchTable testRoutes .get ["users", "nope"] = none
#guard dispatchTable testRoutes .delete ["users", "7"] = none
#guard dispatchTable testRoutes .get ["missing"] = none

end Routing
