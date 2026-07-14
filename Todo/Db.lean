import SQLite

/-!
Schema and CRUD for the todo app's single `todos` table. Thin wrappers over leansqlite's
`sql!`/`exec!`/`query!` interpolation macros (`SQLite/Interpolation.lean` in the `leansqlite`
dependency) -- see `docs/todo-app-plan.md` for why this dependency and this shape.
-/

namespace Todo

/-- One row of the `todos` table. `SQLite.Row`'s deriving handler reads each field in
declaration order via its `ResultColumn` instance, exactly as leansqlite's own test suite does for
its `Person`/`Product` example rows. -/
structure Item where
  id : Int64
  title : String
  completed : Bool
deriving Repr, SQLite.Row

/-- Creates the `todos` table if it doesn't already exist. Call once at startup. -/
def initSchema (db : SQLite) : IO Unit :=
  db.exec "
    CREATE TABLE IF NOT EXISTS todos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      completed INTEGER NOT NULL DEFAULT 0
    )"

/-- Which subset of todos a page/fragment should render -- mirrors TodoMVC's All/Active/Completed
views. -/
inductive Filter where
  | all
  | active
  | completed
deriving Repr, BEq, Inhabited

/-- Lists todos matching `filter`, oldest first. -/
def list (db : SQLite) (filter : Filter) : IO (Array Item) := do
  let stmt ← match filter with
    | .all => db.prepare "SELECT id, title, completed FROM todos ORDER BY id"
    | .active => db.prepare "SELECT id, title, completed FROM todos WHERE completed = 0 ORDER BY id"
    | .completed => db.prepare "SELECT id, title, completed FROM todos WHERE completed = 1 ORDER BY id"
  stmt.results.toArray

/-- Inserts a new todo with the given title (initially not completed). A no-op if `title`,
trimmed, is empty -- TodoMVC's "don't add blank todos" rule. -/
def add (db : SQLite) (title : String) : IO Unit := do
  let title := title.trimAscii.toString
  if title.isEmpty then
    pure ()
  else
    db exec!"INSERT INTO todos (title) VALUES ({title})"

/-- Toggles one todo's completed state. -/
def toggle (db : SQLite) (id : Int64) : IO Unit :=
  db exec!"UPDATE todos SET completed = NOT completed WHERE id = {id}"

/-- Deletes one todo. -/
def delete (db : SQLite) (id : Int64) : IO Unit :=
  db exec!"DELETE FROM todos WHERE id = {id}"

/-- Sets a todo's title (used to save an inline edit). If the trimmed title is empty, deletes the
todo instead -- TodoMVC's rule for clearing a title during an edit. -/
def setTitle (db : SQLite) (id : Int64) (title : String) : IO Unit := do
  let title := title.trimAscii.toString
  if title.isEmpty then
    delete db id
  else
    db exec!"UPDATE todos SET title = {title} WHERE id = {id}"

/-- If any todo is active, marks all as completed; otherwise marks all as active -- TodoMVC's
"toggle all" semantics. Wrapped in a transaction since it's a read followed by a write that must
observe a consistent snapshot. -/
def toggleAll (db : SQLite) : IO Unit :=
  db.transaction (do
    let stmt ← db.prepare "SELECT COUNT(*) FROM todos WHERE completed = 0"
    discard stmt.step
    let activeCount ← stmt.columnInt64 (0 : Int32)
    if activeCount > 0 then
      db.exec "UPDATE todos SET completed = 1"
    else
      db.exec "UPDATE todos SET completed = 0")

/-- Deletes every completed todo. -/
def clearCompleted (db : SQLite) : IO Unit :=
  db.exec "DELETE FROM todos WHERE completed = 1"

end Todo
