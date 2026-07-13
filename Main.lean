import Std.Http.Server
import Html
import Htmx
import Routing

open Std Async
open Std Http Server
open Html
open Routing

-- htmx itself, loaded from the official jsDelivr CDN with Subresource
-- Integrity pinned to the fetched version -- without this, the `hx-get`
-- attributes below are just inert data attributes; nothing in the browser
-- knows to act on them.
def htmxScript : ScriptAttrs :=
  { src := "https://cdn.jsdelivr.net/npm/htmx.org@2.0.10/dist/htmx.min.js"
    integrity := some "sha384-H5SrcfygHmAuTDZphMHqBJLc3FhssKjG7w/CeCpFReSfwBWDTKpkzPP8c+cLsK+V"
    crossorigin := some "anonymous" }

-- `Htmx.button` is used qualified (not `open Htmx`) specifically to show
-- an Htmx tag and a plain Html tag composing in the same list with no
-- special glue -- `Htmx.button`'s result is a plain `Html.Node .phrasing`
-- (docs/html-library-plan.md 1.4/Phase 6), so it needs none.
def page : String :=
  document (pretty := true) "Hey there ;-)"
    [ h1 ["Hey there ;-)"],
      p ["Served by a ", strong ["typed"], " HTML library." ],
      Htmx.button ["Ping"] { hxGet := some "/ping", hxTarget := some "#result", hxSwap := some .innerHTML },
      div [] { id := some "result" } ]
    (scripts := [htmxScript])
    (lang := some "en")

def pingFragment : String :=
  Node.render (strong ["pong"])

def helloPage (name : String) : String :=
  document (pretty := true) s!"Hello, {name}"
    [ h1 [s!"Hello, {name}!"],
      p [ "This page came from a ", strong ["typed path capture"],
          s!": /hello/:name:String matched \"{name}\"." ] ]
    (lang := some "en")

-- A small route table demonstrating the `Routing` library
-- (docs/routing-design-plan.md): a plain literal route, a literal route
-- used as an htmx fragment target, and a route with a statically-typed
-- `String` capture -- `helloPage` receives an ordinary `String` argument,
-- not a raw path segment, because `route`/`HandlerType` already checked
-- the handler's arity and capture types against the
-- `/hello/:name:String` pattern when this table was built.
def routes : List (Route Result) :=
  [ route .get "/" (Response.ok.html page : Result),
    route .get "/ping" (Response.ok.html pingFragment : Result),
    route .get "/hello/:name:String" (fun (name : String) => (Response.ok.html (helloPage name) : Result)) ]

def main : IO Unit := Async.block do
  let addr : Net.SocketAddress := .v4 ⟨.ofParts 127 0 0 1, 2000⟩
  let server ← Server.serve addr (toHandler routes)
  server.waitShutdown
