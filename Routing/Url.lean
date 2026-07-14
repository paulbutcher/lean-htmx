import Routing.Pattern

/-!
Reverse routing: generating a URL from a route pattern and typed arguments, the mirror image of
`HandlerType`/`dispatch` (`Handler.lean`). Where a handler *consumes* a matched path to produce
typed arguments, a URL-builder *consumes* typed arguments to produce a path -- same `segs`, same
per-capture currying shape, opposite direction. Deferred at v1 (`Routing.lean`'s module docstring,
`docs/routing-design-plan.md` §5) pending confirmation that it's additive over plain `List PathSeg`
data; it is, since `UrlType`/`renderUrl` need nothing beyond what `Pattern.lean` already produces.
-/

namespace Routing

/-- The Lean function type a URL-builder for `segs` has: one argument per capture segment (typed
via `CaptureKind.type`, same as `HandlerType`), literal segments contribute nothing to the arity,
and the whole thing returns the built path as a `String`. -/
def UrlType : List PathSeg → Type
  | [] => String
  | .lit _ :: rest => UrlType rest
  | .capture _ .nat :: rest => Nat → UrlType rest
  | .capture _ .string :: rest => String → UrlType rest

/-- Folds `segs` into a `UrlType segs`, appending each literal verbatim and each capture's argument
(as it's supplied) onto the accumulated path. The empty-accumulator, empty-segs case is the root
path `"/"`, matching `renderPattern`'s convention for `[]` (`Pattern.lean`). -/
def renderUrl (segs : List PathSeg) (acc : String) : UrlType segs :=
  match segs with
  | [] => if acc.isEmpty then "/" else acc
  | .lit s :: rest => renderUrl rest (acc ++ "/" ++ s)
  | .capture _ .nat :: rest => fun (n : Nat) => renderUrl rest (acc ++ "/" ++ toString n)
  | .capture _ .string :: rest => fun (s : String) => renderUrl rest (acc ++ "/" ++ s)

/-- Builds a typed URL-builder from a pattern *string*, parsed the same way `route` (`Route.lean`)
parses its pattern. Passing the same string literal used for a route's pattern gives a URL-builder
whose argument types are guaranteed to match that route's captures -- a wrong-arity/wrong-type call
site is a compile error, exactly like a wrong-arity handler (`Handler.lean`'s `badArity`
regression). -/
def routeUrl (pattern : String) : UrlType (parsePattern! pattern) :=
  renderUrl (parsePattern! pattern) ""

private def userPattern : List PathSeg := parsePattern! "/users/:id:Nat"

private def userUrl : UrlType userPattern := renderUrl userPattern ""

-- #guard tests: root, literal-only, single capture, mixed literal/capture patterns. Each result is
-- bound to its own top-level `String`-typed `def` first, rather than compared inline: `UrlType segs`
-- only reduces to a concrete `String` via *elaboration* (default transparency, unfolding ordinary
-- `def`s -- `docs/routing-design-plan.md` §2), and `#guard`'s `Decidable` instance search runs at a
-- more restricted transparency that won't perform that reduction itself, even given an inline type
-- ascription; binding the reduction into its own `def` first sidesteps that.
private def rootUrl : String := routeUrl "/"
private def todosUrl : String := routeUrl "/todos"
private def userUrlResult : String := userUrl 42
private def userUrlViaRouteUrl : String := routeUrl "/users/:id:Nat" 42
private def userPostUrl : String := routeUrl "/users/:id:Nat/posts/:slug:String" 7 "hello"

#guard rootUrl = "/"
#guard todosUrl = "/todos"
#guard userUrlResult = "/users/42"
#guard userUrlViaRouteUrl = "/users/42"
#guard userPostUrl = "/users/7/posts/hello"

-- Negative-compile regression, mirroring `Handler.lean`'s `badArity`: a wrong-arity URL-builder
-- against a real pattern is rejected at compile time, the reverse-routing counterpart to a
-- wrong-arity handler being rejected.
/--
error: Type mismatch
  fun _id _extra => "oops"
has type
  Nat → String → String
but is expected to have type
  UrlType userPattern
-/
#guard_msgs in
def badUrlArity : UrlType userPattern :=
  fun (_id : Nat) (_extra : String) => "oops"

end Routing
