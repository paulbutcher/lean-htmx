import Std.Http.Server
import Html

open Std Async
open Std Http Server
open Html

def page : String :=
  document "Hey there ;-)"
    [ h1 [Node.text "Hey there ;-)"],
      p [Node.text "Served by a ", strong [Node.text "typed"], Node.text " HTML library." ] ]
    (lang := some "en")

def main : IO Unit := Async.block do
  let addr : Net.SocketAddress := .v4 ⟨.ofParts 127 0 0 1, 8080⟩
  let server ← Server.serve addr (Handler.ofFn fun _ => Response.ok |>.html page)
  server.waitShutdown
