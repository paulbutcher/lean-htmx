import Lean
import Routing.Pattern

/-!
Reverse routing: generating a URL from a route pattern and typed arguments, the mirror image of
`HandlerType`/`dispatch` (`Handler.lean`). Where a handler *consumes* a matched path to produce
typed arguments, a URL-builder *consumes* typed arguments to produce a path -- same `segs`, same
per-capture currying shape, opposite direction. Deferred at v1 (`Routing.lean`'s module docstring,
`docs/routing-design-plan.md` §5) pending confirmation that it's additive over plain `List PathSeg`
data; it is, since `UrlType`/`renderUrl` need nothing beyond what `Pattern.lean` already produces.

`routeUrl` is a literal-only macro, not a plain `def` -- see `Routing/Route.lean`'s module
docstring (`docs/reverse-routing-macro-tasks.md` §2.4) for the full rationale and the two things
the throwaway spike behind it found. Unlike `Route.get`/etc., `routeUrl` is a bare (non-dotted)
identifier, so it isn't affected by the dot-notation gap that dropped `route`/`.get` from the
public API there -- ordinary application (`routeUrl "..." 42`) parses and elaborates through the
macro the same way a plain function call would, confirmed directly rather than assumed.
-/

namespace Routing

open Lean

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

/-- Builds a typed URL-builder from an already-macro-validated pattern *string*, unconditionally.
Not part of the public API -- only ever called from the `routeUrl` macro below, immediately after
it's already confirmed (via `parsePattern`, at macro-expansion time) that `pattern` is well-formed,
which is what makes the `.getD []` fallback here dead code in practice. -/
private def buildUrl (pattern : String) : UrlType ((parsePattern pattern).getD []) :=
  renderUrl ((parsePattern pattern).getD []) ""

/-- Builds a typed URL-builder from a pattern *string literal*, parsed the same way
`Route.get`/etc. (`Routing/Route.lean`) parse theirs. Passing the same literal used for a route's
pattern gives a URL-builder whose argument types are guaranteed to match that route's captures --
a wrong-arity/wrong-type call site is a compile error, exactly like a wrong-arity handler
(`Handler.lean`'s `badArity` regression); a malformed literal is a macro-time error, exactly like
`Route.get`'s (see the module docstring, and `Route.lean`'s module docstring for why this is a
macro rather than a plain `def`). -/
-- `:max` is load-bearing, not decorative -- confirmed by direct compilation: without it, this
-- production defaults to too low a precedence for the ordinary `app` trailing-parser to extend it
-- with further arguments, so `routeUrl "/users/:id:Nat" 42` parses as *two* commands (`routeUrl
-- "/users/:id:Nat"`, a stray `42`) instead of one application -- exactly the capture-argument
-- currying every `UrlType`-returning call site here relies on.
syntax:max "routeUrl" str : term
macro_rules
  | `(routeUrl $pat:str) => do
    let s := pat.getString
    match parsePattern s with
    | some _ => `(buildUrl $pat)
    | none =>
      Macro.throwErrorAt pat
        s!"routes: malformed route pattern {s.quote} -- expected a leading '/', no \
          doubled/trailing '/', and every capture written as ':name:Nat' or ':name:String'"

private def userPattern : List PathSeg := (parsePattern "/users/:id:Nat").getD []

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

-- A malformed literal is a macro-time error, never a silent fall-through to the root pattern.
--
-- Takes a dummy `Unit` argument -- see `Route.lean`'s `badPattern` for why a bare nullary `String`
-- value here would get eagerly forced (and panic on its `sorryAx` stub) at every `webapp` startup,
-- despite nothing ever calling it.
/--
error: routes: malformed route pattern "users/:id:Nat" -- expected a leading '/', no doubled/trailing '/', and every capture written as ':name:Nat' or ':name:String'
-/
#guard_msgs in
def badUrlPattern (_ : Unit) : String := routeUrl "users/:id:Nat"

end Routing
