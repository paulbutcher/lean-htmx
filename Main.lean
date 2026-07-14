import Std.Http.Server
import SQLite
import Html
import Routing
import Forms
import Todo

open Std Async
open Std Http Server
open Html
open Routing
open Forms

def render (urls : Todo.Urls) (db : SQLite) (filter : Todo.Filter)
    (renderHtml : Todo.Urls → Array Todo.Item → Array Todo.Item → Todo.Filter → String) :
    ContextAsync (Response Body.Any) := do
  let items ← Todo.list db filter
  let allItems ← Todo.list db .all
  Response.ok.html (renderHtml urls items allItems filter)

/-- Renders the fragment for the filter the client's currently viewing (`HX-Current-URL`) --
what every mutating route responds with. -/
def renderMutation (urls : Todo.Urls) (db : SQLite) (req : Request Body.Stream) :
    ContextAsync (Response Body.Any) :=
  let currentFilter := match req.line.headers.get? (.ofString! "hx-current-url") with
  | some v => Todo.filterFromPath v.value
  | none => .all
  render urls db currentFilter Todo.mutationFragment

def pageHandler (filter : Todo.Filter) (urls : Todo.Urls) (db : SQLite)
    (_req : Request Body.Stream) : ContextAsync (Response Body.Any) :=
  render urls db filter Todo.page

def addHandler (urls : Todo.Urls) (db : SQLite) (req : Request Body.Stream) :
    ContextAsync (Response Body.Any) := do
  let title ← formField req "title"
  Todo.add db title
  renderMutation urls db req

/-- Swaps one todo's `<li>` into edit mode. Not a mutation (nothing in the DB changes), so unlike
every other route below it targets and returns just that one item, not the whole list section. -/
def editHandler (urls : Todo.Urls) (db : SQLite) (id : Nat) (_req : Request Body.Stream) :
    ContextAsync (Response Body.Any) := do
  let items ← Todo.list db .all
  match items.find? (fun item => item.id == Int64.ofNat id) with
  | some item => Response.ok.html (Node.render (Todo.itemEditView urls item))
  | none => Response.notFound.text "Not Found"

def saveHandler (urls : Todo.Urls) (db : SQLite) (id : Nat) (req : Request Body.Stream) :
    ContextAsync (Response Body.Any) := do
  let title ← formField req "title"
  Todo.setTitle db (Int64.ofNat id) title
  renderMutation urls db req

def toggleHandler (urls : Todo.Urls) (db : SQLite) (id : Nat) (req : Request Body.Stream) :
    ContextAsync (Response Body.Any) := do
  Todo.toggle db (Int64.ofNat id)
  renderMutation urls db req

def deleteHandler (urls : Todo.Urls) (db : SQLite) (id : Nat) (req : Request Body.Stream) :
    ContextAsync (Response Body.Any) := do
  Todo.delete db (Int64.ofNat id)
  renderMutation urls db req

def toggleAllHandler (urls : Todo.Urls) (db : SQLite) (req : Request Body.Stream) :
    ContextAsync (Response Body.Any) := do
  Todo.toggleAll db
  renderMutation urls db req

def clearCompletedHandler (urls : Todo.Urls) (db : SQLite) (req : Request Body.Stream) :
    ContextAsync (Response Body.Any) := do
  Todo.clearCompleted db
  renderMutation urls db req

-- `"/"`/`"/active"`/`"/completed"` need `as index`/`as active`/`as completed` even though the
-- design doc's own worked example leaves them unnamed -- `Todo.Urls` (Phase 1) already has those
-- three fields, and a node only contributes a `Urls` field via an explicit `as name` (plan doc
-- §3), so omitting them here would leave `urls` missing required fields (confirmed directly
-- against this toolchain: `RoutesMacro.lean`'s module docstring).
routes! (db : SQLite) : Todo.Urls where
  "/" as index { get => pageHandler .all }
  "/active" as active { get => pageHandler .active }
  "/completed" as completed { get => pageHandler .completed }
  "/todos" as todos {
    post => addHandler
    "/:id:Nat" as todo {
      put => saveHandler
      delete => deleteHandler
      "/edit" as todoEdit { get => editHandler }
      "/toggle" as todoToggle { post => toggleHandler }
    }
    "/toggle-all" as toggleAll { post => toggleAllHandler }
    "/completed" as clearCompleted { delete => clearCompletedHandler }
  }

def main : IO Unit := Async.block do
  let db ← SQLite.open ":memory:"
  Todo.initSchema db
  let addr := .v4 ⟨.ofParts 127 0 0 1, 2000⟩
  let handler := routes db |> toHandler
  serve addr handler >>= waitShutdown
