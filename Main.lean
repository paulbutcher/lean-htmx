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

def currentFilter (req : Request Body.Stream) : Todo.Filter :=
  match req.line.headers.get? (.ofString! "hx-current-url") with
  | some v => Todo.filterFromPath v.value
  | none => .all

def pageResponse (db : SQLite) (filter : Todo.Filter) : ContextAsync (Response Body.Any) := do
  let items ← Todo.list db filter
  Response.ok.html (Todo.page filter items)

def mutationResponse (db : SQLite) (filter : Todo.Filter) : ContextAsync (Response Body.Any) := do
  let items ← Todo.list db filter
  Response.ok.html (Todo.mutationFragment items filter)

def homeHandler (db : SQLite) (_req : Request Body.Stream) : ContextAsync (Response Body.Any) :=
  pageResponse db .all

def activeHandler (db : SQLite) (_req : Request Body.Stream) : ContextAsync (Response Body.Any) :=
  pageResponse db .active

def completedHandler (db : SQLite) (_req : Request Body.Stream) : ContextAsync (Response Body.Any) :=
  pageResponse db .completed

def addHandler (db : SQLite) (req : Request Body.Stream) : ContextAsync (Response Body.Any) := do
  let title ← formField req "title"
  Todo.add db title
  mutationResponse db (currentFilter req)

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
  mutationResponse db (currentFilter req)

def toggleHandler (db : SQLite) (id : Nat) (req : Request Body.Stream) :
    ContextAsync (Response Body.Any) := do
  Todo.toggle db (Int64.ofNat id)
  mutationResponse db (currentFilter req)

def deleteHandler (db : SQLite) (id : Nat) (req : Request Body.Stream) :
    ContextAsync (Response Body.Any) := do
  Todo.delete db (Int64.ofNat id)
  mutationResponse db (currentFilter req)

def toggleAllHandler (db : SQLite) (req : Request Body.Stream) : ContextAsync (Response Body.Any) := do
  Todo.toggleAll db
  mutationResponse db (currentFilter req)

def clearCompletedHandler (db : SQLite) (req : Request Body.Stream) :
    ContextAsync (Response Body.Any) := do
  Todo.clearCompleted db
  mutationResponse db (currentFilter req)

def routes (db : SQLite) : List (Route Result) :=
  [ route .get "/" (homeHandler db),
    route .get "/active" (activeHandler db),
    route .get "/completed" (completedHandler db),
    route .post "/todos" (addHandler db),
    route .get "/todos/:id:Nat/edit" (editHandler db),
    route .put "/todos/:id:Nat" (saveHandler db),
    route .post "/todos/:id:Nat/toggle" (toggleHandler db),
    route .delete "/todos/:id:Nat" (deleteHandler db),
    route .post "/todos/toggle-all" (toggleAllHandler db),
    route .delete "/todos/completed" (clearCompletedHandler db) ]

def main : IO Unit := Async.block do
  let db ← SQLite.open ":memory:"
  Todo.initSchema db
  let addr := .v4 ⟨.ofParts 127 0 0 1, 2000⟩
  let handler := toHandler (routes db)
  let server <- serve addr handler
  server.waitShutdown
