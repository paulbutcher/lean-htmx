import Std.Http.Server
import Html
import Htmx

open Std Async
open Std Http Server
open Html

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
    (lang := some "en")

def main : IO Unit := Async.block do
  let addr : Net.SocketAddress := .v4 ⟨.ofParts 127 0 0 1, 2000⟩
  let server ← Server.serve addr (Handler.ofFn fun _ => Response.ok |>.html page)
  server.waitShutdown
