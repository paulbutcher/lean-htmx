import Std.Http.Server
import Routing.Route

/-!
Wiring a route table into `Std.Http.Server.Handler`
(`docs/routing-design-plan.md` §5's last deferred piece): decoding the
incoming request's method and path and running `dispatchTable` against
it, falling back to a `404` when nothing matches.
-/

namespace Routing

open Std Async
open Std Http Server

/-- The result type routes produce once wired into a server: an in-flight
response action, matching `Handler.ofFn`'s expected codomain. -/
abbrev Result := ContextAsync (Response Body.Any)

/-- Default `404 Not Found` response used by `toHandler` when no route
matches. -/
def defaultNotFound : Result :=
  Response.notFound.text "Not Found"

/-- Wires a route table into a `Std.Http.Server.Handler`: decodes the
incoming request's method and path (`RequestTarget.path.toDecodedSegments`
feeds `dispatch` via `dispatchTable`), tries each route in order, and
falls back to `notFound` if nothing matches. -/
def toHandler (routes : List (Route Result)) (notFound : Result := defaultNotFound) :
    StatelessHandler :=
  Handler.ofFn fun request =>
    let path := request.line.uri.path.toDecodedSegments.toList
    match dispatchTable routes request.line.method path with
    | some result => result
    | none => notFound

end Routing
