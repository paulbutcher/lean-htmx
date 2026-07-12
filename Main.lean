import Std.Http.Server

open Std Async
open Std Http Server

def main : IO Unit := Async.block do
  let addr : Net.SocketAddress := .v4 ⟨.ofParts 127 0 0 1, 8080⟩
  let server ← Server.serve addr (Handler.ofFn fun _ => Response.ok |>.text "Hey there ;-)")
  server.waitShutdown
