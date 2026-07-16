import SQLite

namespace Todo

structure Item where
  id : Int64
  title : String
  completed : Bool
deriving Repr, SQLite.Row

def initSchema (db : SQLite) : IO Unit :=
  db.exec "
    CREATE TABLE IF NOT EXISTS todos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      completed INTEGER NOT NULL DEFAULT 0
    )"

inductive Filter where
  | all
  | active
  | completed
deriving Repr, BEq

def list (db : SQLite) (filter : Filter) : IO (Array Item) := do
  let stmt ← match filter with
    | .all => db.prepare "SELECT id, title, completed FROM todos ORDER BY id"
    | .active => db.prepare "SELECT id, title, completed FROM todos WHERE completed = 0 ORDER BY id"
    | .completed => db.prepare "SELECT id, title, completed FROM todos WHERE completed = 1 ORDER BY id"
  stmt.results.toArray

def add (db : SQLite) (title : String) : IO Unit := do
  let title := title.trimAscii.toString
  if title.isEmpty then -- TodoMVC's "don't add blank todos" rule
    pure ()
  else
    db exec!"INSERT INTO todos (title) VALUES ({title})"

def toggle (db : SQLite) (id : Int64) : IO Unit :=
  db exec!"UPDATE todos SET completed = NOT completed WHERE id = {id}"

def delete (db : SQLite) (id : Int64) : IO Unit :=
  db exec!"DELETE FROM todos WHERE id = {id}"

def setTitle (db : SQLite) (id : Int64) (title : String) : IO Unit := do
  let title := title.trimAscii.toString
  if title.isEmpty then
    delete db id
  else
    db exec!"UPDATE todos SET title = {title} WHERE id = {id}"

/-- If any todo is active, marks all as completed; otherwise marks all as active -- TodoMVC's
"toggle all" semantics. -/
def toggleAll (db : SQLite) : IO Unit :=
  db.transaction (do
    let stmt ← db.prepare "SELECT COUNT(*) FROM todos WHERE completed = 0"
    discard stmt.step
    let activeCount ← stmt.columnInt64 (0 : Int32)
    if activeCount > 0 then
      db.exec "UPDATE todos SET completed = 1"
    else
      db.exec "UPDATE todos SET completed = 0")

def clearCompleted (db : SQLite) : IO Unit :=
  db.exec "DELETE FROM todos WHERE completed = 1"

end Todo
