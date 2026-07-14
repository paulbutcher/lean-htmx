import Routing

/-!
The `Urls` bundle every `Todo.Views` function takes a URL-builder argument shaped like
(`Todo/Views.lean`), plus a concrete value of it for `TodoTests` to exercise those functions
against.

## Where the canonical route patterns live now

As of `docs/reverse-routing-macro-tasks.md` Phase 2, the canonical pattern text for every route
lives in exactly one place: `Main.lean`'s `routes!` block, which generates both the dispatch table
(`def routes`) and its own `Urls` value (`def urls`) from that single written tree -- this file no
longer hand-declares `*Pattern` string constants, since nothing outside `Main.lean` needs the
pattern text anymore (`Todo.Views` only needs the `Urls` *type*, not the patterns that build it;
see below for why even that can't come from `Main.lean`).

## Why `structure Urls` (the type) still lives here, not in `Main.lean`

`Todo/Views.lean` needs `Urls` as a type for its function signatures (`urls : Urls`), and can never
import `Main.lean`: `Main.lean`'s handlers need `Todo.Views` (to render responses), so
`Views → Main → Views` would be an import cycle. The struct *type* -- field names and argument
shapes, no pattern text -- therefore has to be declared somewhere on the leaf side of that cut, by
hand (`docs/reverse-routing-macro-plan.md` §6.2). This is small, low-churn boilerplate (it only
changes when a route's capture arity changes, or a route gains/loses a `Todo.Views` consumer), and
a mismatch between it and what `routes!` builds in `Main.lean` is a plain structure-literal type
error at that `routes!` call site -- compiler-caught, not silent drift.

## Why `def urls`'s *value* is hand-duplicated here too, deliberately

`TodoTests/Views.lean` needs a concrete `Urls` value to call `Todo.Views` functions against, and
has the same import-direction problem `Todo.Views` does: it can't import `Main.lean` either.
Tried directly rather than assumed (`docs/reverse-routing-macro-tasks.md` §2.3): adding
`import Main` to a `TodoTests` file *does* compile (there's no actual import cycle -- `Main` is a
`lean_exe` root, not a `lean_lib`, and `TodoTests → Main → Todo` doesn't loop back through `Todo`).
But it pulls `Std.Http.Server`, `Forms`, and everything else `Main.lean` needs to run a server into
`TodoTests`'s build graph, solely to read one static value -- a real, avoidable compile-time
coupling (and a backwards one: a `Todo`-domain test suite depending on the top-level executable
entrypoint), rejected in favor of the cost below.

The value here is therefore a **deliberately duplicated, hand-synced fixture**, scoped only to what
`TodoTests` needs (not the full pattern-visibility goal `Main.lean`'s `routes!` block still owns).
If a route's pattern ever changes in `Main.lean`'s `routes!` block, this value has to be updated by
hand to match -- unlike `Main.lean`'s own `urls`, nothing here checks the two stay in sync beyond
`TodoTests/Views.lean`'s own `#guard`s catching a rendered string that no longer matches what a
route actually dispatches on.
-/

namespace Todo

open Routing

structure Urls where
  index          : String
  active         : String
  completed      : String
  todos          : String
  todoEdit       : Nat → String
  todo           : Nat → String
  todoToggle     : Nat → String
  toggleAll      : String
  clearCompleted : String

/-- Deliberately duplicated against `Main.lean`'s `routes!`-generated `urls` -- see the module
docstring for why. Must be kept hand-synced with `Main.lean`'s `routes!` block. -/
def urls : Urls :=
  { index := routeUrl "/", active := routeUrl "/active", completed := routeUrl "/completed",
    todos := routeUrl "/todos", todoEdit := routeUrl "/todos/:id:Nat/edit",
    todo := routeUrl "/todos/:id:Nat", todoToggle := routeUrl "/todos/:id:Nat/toggle",
    toggleAll := routeUrl "/todos/toggle-all", clearCompleted := routeUrl "/todos/completed" }

#guard urls.index = "/"
#guard urls.active = "/active"
#guard urls.completed = "/completed"
#guard urls.todos = "/todos"
#guard urls.todoEdit 7 = "/todos/7/edit"
#guard urls.todo 7 = "/todos/7"
#guard urls.todoToggle 7 = "/todos/7/toggle"
#guard urls.toggleAll = "/todos/toggle-all"
#guard urls.clearCompleted = "/todos/completed"

end Todo
