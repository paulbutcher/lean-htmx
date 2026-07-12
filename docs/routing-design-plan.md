# HTTP routing design — options & spike findings

Context for a fresh session: this repo (`webapp`) is a small Lean 4 project
(`leanprover/lean4:v4.31.0`, zero external lake dependencies) with a minimal
`Std.Http.Server`-based server in `Main.lean`, plus a typed HTML library
under construction (see `docs/html-library-plan.md`). This document covers
a design session on how routing should work: what a request dispatcher
looks like in front of `Std.Http.Server.Handler`'s
`Request Body.Stream → ContextAsync (Response Body.Any)`, and specifically
whether captured path segments (`/users/:id`) can be statically typed
without the Haskell-style type-level machinery Servant needs. A throwaway
spike (deleted; this is the memory of what it found) tested the core
mechanism before committing to it — same discipline as the HTML library's
Phase 0 spike.

## 1. Three reference designs considered, and why

**Servant (Haskell):** API described as a *type* (`"users" :> Capture "id"
Nat :> Get '[JSON] User`), server/client/docs all derived from that one
type via typeclass instance search (`HasServer`). Needs DataKinds, type
families, and kind-polymorphism specifically because Haskell types can't
depend on values — the whole type-level encoding is a workaround for that
limitation.

**Yesod (Haskell):** Template-Haskell-generated `Route` sum type from a
routes-file DSL, giving type-safe *reverse* routing — `@{RouteConstructor}`
in templates can never reference a URL that doesn't exist. This is Yesod's
actual differentiator over Servant, and it would pair unusually well with
this repo's `Html` library (`href` built from a `Route` value instead of a
string literal) — but it requires real elaborator/macro work, not just a
combinator library.

**Compojure (Clojure):** untyped, low-ceremony route table
(`(GET "/users/:id" [id] ...)`), captures come out as plain strings, no
static shape checking at all.

**Decision for v1: Compojure's low-ceremony shape, with typed captures.**
Lean has genuine dependent types — unlike Haskell, a `Type` can be computed
directly from an ordinary *value* (no DataKinds needed to fake it), which
is exactly the "type-safe `printf`" trick from Idris. That suggested route
patterns could stay simple runtime data (Compojure's ergonomics) while
still rejecting a wrong-arity/wrong-type handler at compile time (Servant's
guarantee) — without writing a macro. Full Servant-style API-as-a-value and
Yesod-style reverse routing are both deferred; routes staying plain data
means neither is foreclosed later.

## 2. Core mechanism, spiked and confirmed: type computed from a value

```
inductive CaptureKind := | nat | string
def CaptureKind.type : CaptureKind → Type := fun | .nat => Nat | .string => String

inductive PathSeg := | lit (s : String) | capture (name : String) (kind : CaptureKind)

def HandlerType (segs : List PathSeg) (result : Type) : Type :=
  match segs with
  | []                        => result
  | .lit _ :: rest            => HandlerType rest result
  | .capture _ kind :: rest   => kind.type → HandlerType rest result
```

**Confirmed by direct compilation (`rfl`, not just reasoned about):** given
a concrete `segs : List PathSeg`, `HandlerType segs String` reduces all the
way to the expected Pi type, and a handler's argument types are checked
against it with **zero extra machinery** — no macro, no typeclass dispatch
step. Confirmed the actual payoff too, not just the happy path: a
wrong-arity handler against a real pattern —

```
def badArity : HandlerType charPattern String :=
  fun (_id : Nat) (_extra : String) => "oops"
```

— is rejected with `Type mismatch ... Nat → String → String ... but is
expected to have type HandlerType charPattern String`, a genuine
compile-time error pointing at the actual value mismatch.

The other half — matching an incoming request's path segments against a
pattern and applying the handler to the extracted typed values — has to be
hand-written as a dependent fold (Servant gets this for free from
`HasServer` instance resolution; Lean has no equivalent automatic
derivation here, so this is a real, accepted cost, not a gap to close
later):

```
def dispatch {result : Type} :
    (segs : List PathSeg) → HandlerType segs result → List String → Option result
  | [], h, [] => some h
  | .lit s :: rest, h, p :: ps => if s == p then dispatch rest h ps else none
  | .capture _ .nat :: rest, h, p :: ps => (p.toNat?).bind (fun n => dispatch rest (h n) ps)
  | .capture _ .string :: rest, h, p :: ps => dispatch rest (h p) ps
  | _, _, _ => none  -- arity mismatch between segs and the actual path
```

This type-checks because Lean's equation compiler works out, from
`segs`'s constructor in each branch, exactly what Pi-type shape `h`'s type
must have — the same dependent-pattern-matching mechanism `Vector`/`Fin`
rely on elsewhere. Confirmed correct dispatch, correct rejection of a
mistyped capture (`"notanumber"` against a `.nat` segment → `none`, not a
crash), and correct rejection of arity mismatches against the actual path.

## 3. Pitfall found and root-caused: `String.splitOn` does not reduce through defeq

The obvious next step — let route authors write a bare pattern string and
have Lean parse it into `List PathSeg` via `String.splitOn`, so the
"printf" trick applies to source text directly — **does not work on this
toolchain (`v4.31.0`).**

```
def examplePattern := parsePattern "/users/:id:Nat/posts/:slug:String"
example : HandlerType examplePattern String = (Nat → String → String) := by rfl  -- FAILS
```

`rfl` fails outright (not a depth-limit tuning issue — raising
`maxRecDepth` to 4000 changed nothing) and `#reduce HandlerType
examplePattern String` hits `maximum recursion depth has been reached`.

**Root cause, isolated by substitution, not guessed:** it's specifically
`String.splitOn`, not "computing a type from parsed data" in general. Lean
4.31 restructured `String` around a new `String.Slice` type (`String.drop`
now returns `Slice`, not `String`), and whatever recursion scheme the
resulting string operations use does not unfold via ordinary kernel defeq.
Two isolating tests confirmed this precisely:

- A **literal** `List PathSeg` (no string parsing at all) reduces fine —
  `rfl` succeeds, the handler typechecks, no friction.
- A **hand-rolled parser over `List Char`** (plain structural recursion,
  same overall shape as `parsePattern`, just not using `String.splitOn`)
  *also* reduces fine — `rfl` succeeds, `HandlerType charPattern String`
  unfolds correctly, wrong-arity handlers are rejected (§2's example is
  built on this).

**Decision: pattern strings are fine as the authoring surface, but the
parser backing them must not go through core `String.splitOn`/`Slice`
operations — implement it as a structural recursion over `List Char`
instead** (`s.toList`, then a hand-rolled splitter). Same category of
"a priori reasoning turned out wrong" as the HTML library's Node
representation spike (`docs/html-library-plan.md` §1.1) — recorded here so
the same experiment isn't redone. If a future version needs richer pattern
syntax than a hand-rolled `List Char` recursion can comfortably express,
the fallback is doing the parse in an actual `elab`-time macro (parsing
happens in `MetaM`, producing the `List PathSeg` term directly, never
asking the kernel to reduce through it) — more machinery, but a known-good
escape hatch, not yet needed.

## 4. Secondary pitfall: typeclass search is stricter than plain defeq

`BEq`/`Decidable` instance search on a `HandlerType`-computed type (e.g.
`#guard someHandler 7 = "7"`) can fail even when the type genuinely reduces
fine for `rfl`/binder-checking purposes — instance search uses more
conservative unfolding (roughly `.instances` transparency) than ordinary
elaboration. Confirmed concretely: `BEq (HandlerType [] String)` failed to
synthesize even though `HandlerType [] String` is definitionally `String`.
Workaround confirmed sufficient for the spike: mark the small
value-to-`Type` functions (`CaptureKind.type`) `@[reducible]`, or force an
explicit type ascription at the call site rather than relying on inference.
Not a blocker, but expect to hit this again anywhere derived typeclasses
(`BEq`, `Repr`, ...) are asked to work on a `HandlerType`-shaped type rather
than a fully concrete one — same underlying lesson as
`docs/html-library-plan.md` §1.2 (coercion/elaboration order matters more
than it seems like it should whenever a type is *computed* rather than
written literally).

## 5. Not yet decided (deferred, needs its own pass)

- **`CaptureKind` is a closed enum** for the spike (only `Nat`/`String`).
  Whether to make it an open typeclass instead (so downstream code can add
  capture types) is the same closed-vs-open tradeoff already resolved for
  HTML attributes in `docs/html-library-plan.md` §1.2/1.3 — revisit that
  writeup before deciding here rather than re-deriving it.
- **Method dispatch** (`GET`/`POST`/...) and **query-string params** aren't
  designed yet — `dispatch` above only handles the path. `Std.Http.Method`
  is a large closed inductive (see `Std/Http/Data/Method.lean`); dispatch
  on it is ordinary pattern matching, no type-safety questions expected
  there.
- **Wiring into `Std.Http.Server.Handler`** — turning a table of routes
  into the `Request Body.Stream → ContextAsync (Response Body.Any)` shape
  `Handler.ofFn` expects, including how `RequestTarget.path.toDecodedSegments`
  feeds `dispatch`. Not attempted yet.
- **Reverse routing** (Yesod's killer feature, §1) is explicitly deferred.
  Because routes stay plain `List PathSeg` data rather than a type-level
  encoding, generating a URL from a route value later (for use from the
  `Html` library) should be additive, not a rewrite — not yet verified.

## 6. Test strategy note

Same default as the HTML library: `#guard` for behavior, one theorem only
where a universal property isn't already implied by typing. The one thing
worth a real regression test once this is built for real (not just the
spike): a small suite of "should fail to typecheck" cases per §2's
`badArity` example, the same way `docs/html-library-plan.md` Phase 4 wants
for content-model violations — these are cheap correctness insurance for
exactly the property that's the whole point of doing this in Lean instead
of Compojure directly.
