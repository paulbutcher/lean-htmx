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

def render (db : SQLite) (filter : Todo.Filter)
    (renderHtml : Array Todo.Item → Array Todo.Item → Todo.Filter → String) :
    ContextAsync (Response Body.Any) := do
  let items ← Todo.list db filter
  let allItems ← Todo.list db .all
  Response.ok.html (renderHtml items allItems filter)

/-- Renders the fragment for the filter the client's currently viewing (`HX-Current-URL`) --
what every mutating route responds with. -/
def renderMutation (db : SQLite) (req : Request Body.Stream) : ContextAsync (Response Body.Any) :=
  let currentFilter := match req.line.headers.get? (.ofString! "hx-current-url") with
  | some v => Todo.filterFromPath v.value
  | none => .all
  render db currentFilter Todo.mutationFragment

def pageHandler (filter : Todo.Filter) (db : SQLite) (_req : Request Body.Stream) : ContextAsync (Response Body.Any) :=
  render db filter Todo.page

def addHandler (db : SQLite) (req : Request Body.Stream) : ContextAsync (Response Body.Any) := do
  let title ← formField req "title"
  Todo.add db title
  renderMutation db req

/-- Swaps one todo's `<li>` into edit mode. Not a mutation (nothing in the DB changes), so unlike
every other route below it targets and returns just that one item, not the whole list section. -/
def editHandler (db : SQLite) (id : Nat) (_req : Request Body.Stream) :
    ContextAsync (Response Body.Any) := do
  let items ← Todo.list db .all
  match items.find? (fun item => item.id == Int64.ofNat id) with
  | some item => Response.ok.html (Node.render (Todo.itemEditView item))
  | none => Response.notFound.text "Not Found"

def saveHandler (db : SQLite) (id : Nat) (req : Request Body.Stream) :
    ContextAsync (Response Body.Any) := do
  let title ← formField req "title"
  Todo.setTitle db (Int64.ofNat id) title
  renderMutation db req

def toggleHandler (db : SQLite) (id : Nat) (req : Request Body.Stream) :
    ContextAsync (Response Body.Any) := do
  Todo.toggle db (Int64.ofNat id)
  renderMutation db req

def deleteHandler (db : SQLite) (id : Nat) (req : Request Body.Stream) :
    ContextAsync (Response Body.Any) := do
  Todo.delete db (Int64.ofNat id)
  renderMutation db req

def toggleAllHandler (db : SQLite) (req : Request Body.Stream) : ContextAsync (Response Body.Any) := do
  Todo.toggleAll db
  renderMutation db req

def clearCompletedHandler (db : SQLite) (req : Request Body.Stream) :
    ContextAsync (Response Body.Any) := do
  Todo.clearCompleted db
  renderMutation db req

def routes (db : SQLite) : List (Route Result) :=
  [ .get Todo.indexPattern ∘ pageHandler .all,
    .get Todo.activePattern ∘ pageHandler .active,
    .get Todo.completedPattern ∘ pageHandler .completed,
    .post Todo.todosPattern ∘ addHandler,
    .get Todo.todoEditPattern ∘ editHandler,
    .put Todo.todoPattern ∘ saveHandler,
    .post Todo.todoTogglePattern ∘ toggleHandler,
    .delete Todo.todoPattern ∘ deleteHandler,
    .post Todo.toggleAllPattern ∘ toggleAllHandler,
    .delete Todo.clearCompletedPattern ∘ clearCompletedHandler ].map (· db)

def main : IO Unit := Async.block do
  let db ← SQLite.open ":memory:"
  Todo.initSchema db
  let addr := .v4 ⟨.ofParts 127 0 0 1, 2000⟩
  let handler := routes db |> toHandler
  serve addr handler >>= waitShutdown
