import Routing

/-!
Every route pattern the todo app dispatches on, as named `String` constants, plus the typed
URL-builder (`Routing.routeUrl`, `Routing/Url.lean`) each one derives. `Main.lean` passes these same
constants to `Route.get`/`.post`/`.put`/`.delete` when building the route table, and `Todo/Views.lean`
calls the derived `*Url` values instead of hand-building the same paths as string interpolations --
one source of truth for each path instead of two that have to be kept in sync by hand. A renamed
segment, added capture, or `Nat`↔`String` capture-type change here is a compile error at every call
site that no longer matches, the same static guarantee `Routing`'s handlers already have.
-/

namespace Todo

open Routing

def indexPattern : String := "/"
def activePattern : String := "/active"
def completedPattern : String := "/completed"
def todosPattern : String := "/todos"
def todoEditPattern : String := "/todos/:id:Nat/edit"
def todoPattern : String := "/todos/:id:Nat"
def todoTogglePattern : String := "/todos/:id:Nat/toggle"
def toggleAllPattern : String := "/todos/toggle-all"
def clearCompletedPattern : String := "/todos/completed"

def indexUrl : String := routeUrl indexPattern
def activeUrl : String := routeUrl activePattern
def completedUrl : String := routeUrl completedPattern
def todosUrl : String := routeUrl todosPattern
def todoEditUrl : Nat → String := routeUrl todoEditPattern
def todoUrl : Nat → String := routeUrl todoPattern
def todoToggleUrl : Nat → String := routeUrl todoTogglePattern
def toggleAllUrl : String := routeUrl toggleAllPattern
def clearCompletedUrl : String := routeUrl clearCompletedPattern

#guard indexUrl = "/"
#guard activeUrl = "/active"
#guard completedUrl = "/completed"
#guard todosUrl = "/todos"
#guard todoEditUrl 7 = "/todos/7/edit"
#guard todoUrl 7 = "/todos/7"
#guard todoToggleUrl 7 = "/todos/7/toggle"
#guard toggleAllUrl = "/todos/toggle-all"
#guard clearCompletedUrl = "/todos/completed"

end Todo
