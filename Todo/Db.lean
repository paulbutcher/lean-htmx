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

/-! ## Tests

Every function above is `IO` (real SQLite side effects), not the pure functions the rest of this
codebase checks with `#guard` (`Html/Tags.lean`, `Routing/Pattern.lean`, `Forms/FormBody.lean`).
So instead, `#eval` each scenario below against a fresh `:memory:` db, asserting with `checkEq` --
closer to leansqlite's own `tests/TestMain.lean` in spirit (assert-and-fail-loudly), but hand-rolled
rather than reusing its `TestM`: that lives in leansqlite's `tests/` subproject, a separate
non-default target its own `lakefile.lean` deliberately doesn't expose to downstream dependents
(`@[default_target] lean_lib SQLite` only builds `SQLite`), so it isn't available to import here. -/

/-- Fails the surrounding `IO` action -- and so, via `#eval` below, `lake build` itself, exactly
like a failing `#guard` -- unless `expected == actual`. Confirmed (by a throwaway spike) that an
`#eval` of a throwing `IO` action surfaces as a build-breaking elaboration error, not a silent
no-op. -/
private def checkEq [BEq α] [Repr α] (label : String) (expected actual : α) : IO Unit :=
  unless expected == actual do
    throw <| IO.userError s!"{label}: expected {repr expected}, got {repr actual}"

/-- A fresh in-memory db with the schema applied -- every test below starts from empty, and (since
each is a brand new `:memory:` connection) `AUTOINCREMENT` ids restart at 1. -/
private def freshDb : IO SQLite := do
  let db ← SQLite.open ":memory:"
  initSchema db
  pure db

/-- `add`'s "don't add blank todos" rule, and that a non-blank title is trimmed before storing. -/
private def testAddSkipsBlank : IO Unit := do
  let db ← freshDb
  add db "  "
  checkEq "blank title inserts nothing" (#[] : Array String) ((← list db .all).map (·.title))
  add db "  Buy milk  "
  checkEq "non-blank title is trimmed" #["Buy milk"] ((← list db .all).map (·.title))

/-- `setTitle`'s "empty edited title deletes the todo" rule, and that a non-blank edit is trimmed
like `add`. -/
private def testSetTitleEmptyDeletes : IO Unit := do
  let db ← freshDb
  add db "Buy milk"
  let [item] := (← list db .all).toList | throw (IO.userError "expected exactly one item")
  setTitle db item.id "   "
  checkEq "empty edited title deletes the row" (0 : Nat) (← list db .all).size
  add db "Wash car"
  let [item2] := (← list db .all).toList | throw (IO.userError "expected exactly one item")
  setTitle db item2.id "  Wash the car  "
  checkEq "non-blank edited title is trimmed" #["Wash the car"] ((← list db .all).map (·.title))

/-- `toggleAll`'s any-active-completes-all / else-uncompletes-all semantics, including the empty
table (no-op, must not crash). -/
private def testToggleAll : IO Unit := do
  let db ← freshDb
  toggleAll db
  checkEq "toggleAll on empty table" (0 : Nat) (← list db .all).size
  add db "a"; add db "b"
  toggleAll db
  checkEq "toggleAll completes all when any active" #[true, true] ((← list db .all).map (·.completed))
  toggleAll db
  checkEq "toggleAll un-completes all when none active" #[false, false] ((← list db .all).map (·.completed))

/-- `list`'s `.active`/`.completed` filters, and `clearCompleted` removing only completed rows. -/
private def testListFiltersAndClearCompleted : IO Unit := do
  let db ← freshDb
  add db "a"; add db "b"; add db "c"
  let items ← list db .all
  let [x, _y, z] := items.toList | throw (IO.userError "expected exactly three items")
  toggle db x.id
  toggle db z.id
  checkEq "active filter excludes completed" #["b"] ((← list db .active).map (·.title))
  checkEq "completed filter excludes active" #["a", "c"] ((← list db .completed).map (·.title))
  clearCompleted db
  checkEq "clearCompleted removes only completed rows" #["b"] ((← list db .all).map (·.title))

#eval testAddSkipsBlank
#eval testSetTitleEmptyDeletes
#eval testToggleAll
#eval testListFiltersAndClearCompleted

end Todo
