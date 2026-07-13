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

/-- The result type routes produce once wired into a server: a function
from the full incoming request (headers and body included, not just the
path captures `dispatch` already threads through) to an in-flight response
action, matching `Handler.ofFn`'s expected codomain once applied.

`HandlerType segs result` (`Handler.lean`) is purely structural in
`result` -- `[] ↦ result`, `.capture _ kind :: rest ↦ kind.type →
HandlerType rest result` -- so substituting a function type here composes
for free: a handler with captures takes its typed captures *then* the
request, with no change needed to `Handler.lean`/`Route.lean` or their
existing proofs/tests. This is what lets a handler read a POST body
(`request.body.readAll`, see `Forms/FormBody.lean`) or a header (e.g.
htmx's `HX-Current-URL`) without `dispatch` itself needing to know
anything about either. -/
abbrev Result := Request Body.Stream → ContextAsync (Response Body.Any)

/-- Default `404 Not Found` response used by `toHandler` when no route
matches. -/
def defaultNotFound : Result :=
  fun _request => Response.notFound.text "Not Found"

/-- Wires a route table into a `Std.Http.Server.Handler`: decodes the
incoming request's method and path (`RequestTarget.path.toDecodedSegments`
feeds `dispatch` via `dispatchTable`), tries each route in order, and
applies the matched handler (or `notFound`) to the full request. -/
def toHandler (routes : List (Route Result)) (notFound : Result := defaultNotFound) :
    StatelessHandler :=
  Handler.ofFn fun request =>
    let path := request.line.uri.path.toDecodedSegments.toList
    match dispatchTable routes request.line.method path with
    | some handler => handler request
    | none => notFound request

end Routing
