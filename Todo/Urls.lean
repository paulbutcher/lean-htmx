/-!
`Todo.HasUrls`: a capability typeclass giving `Todo.Views`' rendering functions generic access to
an app's reverse-routing URL values, without `Todo` (upstream) depending on the concrete `Urls`
struct `Routing.Application`'s `application` macro generates downstream, in `Main.lean`.

`Main.lean`'s `application app : SQLite deriving Todo.HasUrls where ...` block generates its own
`AppUrls` struct and, because of the `deriving Todo.HasUrls` clause, a mechanical instance mapping
each of `AppUrls`'s fields onto the identically-named method below -- see
`docs/application-macro-plan.md`'s Phase 3 notes on the circular-import problem this solves:
`Todo` can't reference `Main.AppUrls` (that would make `Todo` depend on `Main`, which depends on
`Todo`), so `Todo.Views` is written against this abstract interface instead, and `Main.lean` is the
one place that ties the concrete struct to it.

Method names/types below must match `Todo/Views.lean`'s call sites exactly (`docs/todo-app-plan.md`
patterns) -- a mismatch is a compile error at the `deriving` clause (missing/extra field), not a
silent drift.
-/

namespace Todo

class HasUrls (Urls : Type) where
  index          : Urls → String
  active         : Urls → String
  completed      : Urls → String
  todos          : Urls → String
  todo           : Urls → Nat → String
  todoEdit       : Urls → Nat → String
  todoToggle     : Urls → Nat → String
  toggleAll      : Urls → String
  clearCompleted : Urls → String

end Todo
