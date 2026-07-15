import Routing.Pattern
import Routing.Handler
import Routing.Route
import Routing.Server
import Routing.Url
import Routing.Application

/-!
# `Routing`: a typed HTTP path router

Compojure's low-ceremony shape (`route .get "/users/:id:Nat" handler`),
with Servant's static guarantee that a wrong-arity/wrong-type handler is a
compile error -- without writing a macro. See
`docs/routing-design-plan.md` for the full design rationale (three
reference designs considered, the throwaway spike that confirmed the core
mechanism, and two pitfalls found and root-caused on this toolchain); this
is a short orientation for someone reading the code.

## Design overview

A route pattern string (`"/users/:id:Nat"`) parses (`Routing/Pattern.lean`)
into `List PathSeg`, plain runtime data -- no type-level encoding. From
that *value*, `HandlerType segs result` (`Routing/Handler.lean`) computes
the *type* a matching handler must have (one argument per capture,
correctly typed via `CaptureKind.type`), using Lean's dependent types
directly -- unlike Haskell/Servant, no DataKinds or type families are
needed to compute a type from a value. A handler with the wrong arity or
capture types is therefore rejected at the point a `Route` is built,
exactly like Servant's `HasServer`-checked API type, but with routes
staying ordinary data (Compojure's ergonomics) rather than a type-level
API description.

What Lean does *not* derive automatically is matching an incoming
request's path against a pattern and applying the handler to the
extracted values -- `dispatch` (`Routing/Handler.lean`) is a hand-written
dependent fold doing that job; Servant gets the equivalent for free from
typeclass instance resolution, Lean does not have that mechanism here.
This is a real, accepted cost of the "no macro" v1 decision (§2 of the
design doc), not a gap expected to close later.

`Route`/`dispatchTable` (`Routing/Route.lean`) bundle a method, pattern,
and handler into a route table, tried in order. `toHandler`
(`Routing/Server.lean`) wires that table into
`Std.Http.Server.Handler.ofFn`'s expected
`Request Body.Stream → ContextAsync (Response Body.Any)` shape, decoding
the request's path via `RequestTarget.path.toDecodedSegments` and falling
back to `404` when nothing matches.

## The one hand-rolled piece of logic, and why

Pattern strings are parsed by a structural recursion over `List Char`
(`Routing/Pattern.lean`), deliberately **not** `String.splitOn`: on this
toolchain (`v4.31.0`, `String` rebuilt around `String.Slice`), a
`String.splitOn`-based parser does not reduce through kernel defeq, which
silently breaks `HandlerType`-computed types built from its output (the
design doc's §3 records the isolated repro). Dispatch and capture typing
are guaranteed by `HandlerType`/the equation compiler with no proof
needed; the hand-rolled parser is the exception, and has a real
`theorem` (`parsePattern_renderPattern`, `Routing/Pattern.lean`) proving it
round-trips on well-formed input, plus `#guard` regressions for malformed
input (doubled/trailing `/`, unknown or missing capture kind, empty
capture name) all failing via `none`, never a panic.

## Reverse routing

`UrlType`/`renderUrl`/`routeUrl` (`Routing/Url.lean`) generate a URL from
a pattern string and typed arguments -- the mirror image of
`HandlerType`/`dispatch`: same `segs`, same per-capture currying shape,
opposite direction (arguments in, path out, instead of path in,
arguments out). Confirms the design doc's prediction that this would be
additive over plain `List PathSeg` data (§5) -- no new type-level
machinery needed beyond what `Pattern.lean` already produces. `routeUrl
pattern` takes the *same* pattern string literal passed to `route`, so a
call site with the wrong argument types/count is a compile error, exactly
like a wrong-arity handler (`Handler.lean`'s `badArity` regression; the
counterpart is `Url.lean`'s `badUrlArity`).

## Not yet supported (deferred, see `docs/routing-design-plan.md` §5)

- **Query-string parameters** -- `dispatch` only matches the path.
- **`CaptureKind` is a closed enum** (`Nat`/`String` only). Whether to open
  it into a typeclass so downstream code can add capture types is
  deferred.

## How to add a route

Add a node to an `application` block (`Routing/Application.lean`,
`docs/application-macro-plan.md`) -- a route-tree command macro that reads as
nested pattern fragments with inline `method => handler` entries and produces
one `Application` value bundling the dispatch handler with a generated
reverse-routing `Urls` struct, so a pattern is written exactly once regardless
of how many methods or nested sub-paths share it:

```
application app : SQLite where
  "/" as index { get => pageHandler .all }
  "/todos" as todos {
    post => addHandler
    "/:id:Nat" as todo { put => saveHandler }
  }
```

`app.urls.todo 7 = "/todos/7"`; `app.handler db` is a `StatelessHandler` ready
for `serve`. See `Main.lean` for a complete, real example, including the
`deriving <ClassName>` clause that lets a library upstream of the file
`application` is invoked in (which can't reference the struct `application`
is about to generate) depend on an abstract typeclass instead
(`docs/application-macro-plan.md`'s Phase 3 notes; `Todo/Urls.lean`).

`route`/`Route.get`/`.post`/`.put`/`.delete` (`Routing/Route.lean`) and
`routeUrl` (`Routing/Url.lean`) are what `application` expands to, not the
recommended top-level API -- call them directly only outside an `application`
block (e.g. a one-off route table with no reverse-routing needs). A pattern
string and a handler whose argument types match each `:name:Kind` capture in
order (`Nat` for `:Nat`, `String` for `:String`) build a `Route`, added to the
`List (Route Result)` `toHandler` (`Routing/Server.lean`) expects; the same
pattern string passed to `routeUrl` builds the matching URL, so the two can
never drift apart.
-/
