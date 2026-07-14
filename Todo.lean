import Todo.Db
import Todo.Urls
import Todo.Views

/-!
# `Todo`: a server-rendered TodoMVC demo

Persists todos in SQLite (`leansqlite`, `Todo/Db.lean`) and renders every page/fragment through
the existing `Html`/`Htmx` libraries (`Todo/Views.lean`). Route *patterns* live in `Todo/Routes.lean`
as named `String` constants, shared by `Main.lean` (which builds the route table from them) and
`Todo/Views.lean` (which builds every link/`hx-*` URL from the same constants via
`Routing.routeUrl`, `Routing/Url.lean`) -- one source of truth instead of two independently
hand-written copies of each path. `Main.lean` also has the `Routing.Result` change
(`Routing/Server.lean`) that threads the full request into every handler -- see
`docs/todo-app-plan.md` for the design rationale.
-/
