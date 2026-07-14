# Typed HTML library for Lean — design summary & implementation plan

Context for a fresh session: this repo (`webapp`) is a small Lean 4 project
(`leanprover/lean4:v4.31.0`, zero external lake dependencies — see
`lake-manifest.json`) currently containing a minimal `Std.Http.Server`-based
server in `Main.lean`. We spent a design session prototyping a Lucid-style
(Haskell) HTML DSL that uses Lean's type system to make illegal HTML
unrepresentable — tags only nesting where the content model allows, and
attributes only existing where they're valid, with correct value types.
Several designs were prototyped and empirically tested (compiled, not just
reasoned about) before settling on an approach. The prototype files have
been deleted; this document is the memory of *why*, so we don't redo the
same experiments. Section 1 is background/decisions, Section 2 is the
concrete task plan for building the real thing.

htmx support and XHTML were explicitly discussed and are **out of scope**
for this phase — see "Deferred" at the end.

## 1. Design decisions and why (read this before designing anything new)

### 1.1 Content model: one phantom type parameter, and it's free

`Node (cat : Category)` — a private-constructor wrapper around a rendered
`String`, indexed by a `Category` (`flow`, `phrasing`, ...). Every tag
function is a smart constructor that only accepts children of the right
category, so nesting rules are enforced at compile time. Content-model
correctness this way is a **corollary of type soundness** — a well-typed
program already satisfies it. This does **not** need a separate runtime
theorem or proof; don't spend proof effort here.

Only `flow` and `phrasing` were modeled in the prototype. Real HTML5 has
more categories (metadata, sectioning, heading, embedded, interactive, ...)
with overlaps, plus the "transparent content model" exception (`<a>`,
`<ins>`, `<del>` inherit whatever their parent allows rather than having a
fixed category of their own). Full fidelity to the spec is a lot of work;
v1 scope needs a deliberate, explicit decision (see Plan, Phase 0).

**Representation risk, not yet resolved:** "private-constructor wrapper
around a rendered `String`" is ambiguous about *when* rendering happens. If
each smart constructor eagerly concatenates its children's already-rendered
strings, nesting depth becomes a classic quadratic string-concatenation
trap (each level re-copies everything below it) — invisible in small
`#guard` examples, real at realistic page sizes (tables, forms, repeated
list items). This needs an explicit decision before Phase 1, not an
accident of implementation order: either confirm eager `String` concat is
fine for v1's expected page sizes, or have `Node` wrap something that defers
flattening (a `String.Builder`/rope, or a small tree of `Array String`
chunks) with a single `render : Node cat → String` at the boundary. The
latter also gets pretty-printing (Phase 6) close to free, since a
structured intermediate can be flattened compactly or indented. See Plan,
Phase 0/1.

### 1.2 Attributes: one concrete type, not a type parameter — this is the load-bearing decision

We tried making `Node` generic over the *attribute vocabulary* too
(`Node (cat : Category) (α : Type)`, or a closed `Dialect := html | htmx`
index), specifically to get a compile-time guarantee that a page typed as
plain HTML can't accidentally use htmx attributes. **This wrecked
ergonomics badly enough that we reverted it.**

Root cause, confirmed by direct reproduction: Lean's automatic coercion
insertion (used for the `phrasing ⊆ flow` `Coe` instance) elaborates an
argument *in isolation* before comparing it to the expected type. If the
`Coe` instance shares a type variable between source and target that is
*still an unresolved metavariable* at that point, Lean hits a rigid
mismatch on the category index and gives up — it does not defer and retry
the coercion once the variable would otherwise be resolved. This is
exactly what happens whenever a phrasing-only tag (`span`, `a`, `button`)
is placed directly among a flow-context element's children — an extremely
common, completely unremarkable authoring pattern (e.g. a badge `<span>`
sitting next to a `<p>` inside a `<div>`, not wrapped in anything). It
produces genuinely bad error messages for someone who doesn't know the
library internals:

```
Application type mismatch: The argument
  span [text "New"]
has type
  Node Category.phrasing ?m.7
but is expected to have type
  Node Category.flow HtmxAttrs
...
```

or, in a different but equally opaque form when the mismatched element also
has a struct-literal attribute argument:

```
invalid {...} notation, expected type is not known
```

Neither message points at the fix (a manual type ascription like
`(span [...] : Node .phrasing HtmxAttrs)` on every such element). This
reproduces regardless of whether the second index is a closed 2-constructor
`Dialect` enum or a fully generic `α` with an open `Attrs α` typeclass — the
generic/typeclass version is *more* extensible (see 1.3) but no more
ergonomic.

**Decision: `Node` keeps exactly one phantom parameter (`Category`).**
`HtmlAttrs` (global attributes: `id`, `class`, ...) is one fixed, concrete
structure, not a type parameter. This makes the `phrasing ⊆ flow` `Coe`
instance fully concrete (no shared unresolved variable), which we verified
removes the friction completely — including for the exact struct-literal
case that broke before.

### 1.3 Extensibility for non-standard attributes/elements: escape hatches, not types

Lean `inductive`/`match` is closed — a downstream package cannot add a case
to a `Dialect` enum or extend a closed `AttrsFor : Dialect → Type` match
defined in an upstream file. Typeclasses *are* open (any package can add an
instance for a new type), which is the mechanism to reach for if you ever
need genuine cross-package extensibility of a *type family* — but per 1.2,
we're avoiding that shape entirely for `Node` itself.

Instead, every tag takes two extra, purely additive, always-optional
arguments that are **ordinary values, not type indices** — so using them
can never affect `Node`'s type or any other call site's ergonomics:

- `rawAttrs : List (String × String) := []` — arbitrary `(name, value)`
  pairs rendered verbatim (value-escaped, name unchecked). Covers `hx-*`,
  `x-*`, ad hoc `data-*`, anything the typed vocabulary doesn't model.
  **Names are assumed to always be literal source-code identifiers, never
  derived from untrusted input** — an attribute name containing a space,
  `=`, or `>` breaks out of the tag regardless of value-escaping, and
  nothing in this library checks for that (Phase 3 decision; see
  `Html.renderRawAttrs`'s `#guard` documenting, not fixing, this).
- `unsafeRaw : String → Node cat` — verbatim, unescaped markup, trusted
  as-is, usable as content of any category. Covers custom elements
  (`<my-widget>`) or embedding a whole third-party snippet. Name it loudly
  (`unsafeRaw`, not `raw`) — misuse with untrusted input is a real XSS hole,
  and that risk should be visible at every call site.

Neither hatch is type-checked, by design. `rawAttrs`/`unsafeRaw` content is
explicitly **out of scope** for any correctness proof written against this
library — document that boundary clearly (e.g. in module docs) so nobody
mistakes "the library has proofs" for "everything you can pass to it is
proven safe."

**URL-valued attributes (`href`, `src`) stay plain `String` for v1**
(Phase 3 decision, `AAttrs`/`ImgAttrs`) — a deliberate non-goal, not a
silent gap: `escape_safe` (Phase 2) defends against markup breakout but
not against a `javascript:`-scheme value, which is a distinct, well-known
injection vector. A dedicated URL type that rejects dangerous schemes is
future work, not v1 scope.

### 1.4 A downstream library (htmx or similar) can still get full type safety — different mechanism than 1.2

Confirmed by prototype: a separate `Htmx` library, built as its own Lake
`lean_lib` importing `Html`, can define its own fully-typed attribute
record (e.g. `HtmxAttrs` with a real closed `HxSwap` enum that genuinely
rejects `hxSwap := some "banana"` at compile time) *without* making `Node`
generic. The trick: `HtmxAttrs` never becomes part of `Node`'s type.
`Htmx.button`, `Htmx.div`, etc. are thin wrappers with the same signature as
`Html.button`/`Html.div` plus one extra typed `hx : HtmxAttrs` parameter;
internally they validate `hx`, flatten it to `List (String × String)`, and
forward to the matching `Html.*` function via `rawAttrs`. `Html.lean` needs
**zero** changes to support this (verified: file untouched, builds and
typechecks fully standalone with no `Htmx` involvement).

Accepted tradeoff, stated explicitly so it isn't rediscovered by surprise
later: this does **not** give a "this whole page is/isn't allowed to use
htmx" static guarantee. `Htmx.button (...) : Html.Node .phrasing` is
type-indistinguishable from plain `Html.button (...)`, so nothing stops
htmx-typed content from ending up in a tree with no other htmx usage. That
guarantee is exactly what 1.2's rejected design would have given, and is
exactly what cost the ergonomics — you cannot have both for free in this
type system without the friction from 1.2. We chose ergonomics.

### 1.5 `private` constructor + one deliberate crossing point (technique, not currently used)

`private` on a constructor is *file/module* scoped: any function defined in
the same file can use it freely and expose a curated public wrapper for
downstream code, even across a package boundary, as long as the wrapper's
soundness is argued explicitly (e.g. "content built only from `HtmlAttrs`
can never contain anything dialect-specific, so relabeling its phantom type
is safe"). We used this (`Node.reinterpretAttrs`) in the design we ended up
rejecting (1.2's generic-`α` version). Not needed in the accepted design,
but worth remembering if a future extension genuinely needs to cross a
sealed boundary.

### 1.6 Void elements — not yet designed

`<br>`, `<img>`, `<input>`, `<hr>`, `<meta>`, `<link>`, etc. take no
children and self-close. The prototype never modeled this — every tag
function so far takes a `children` list and renders an explicit closing
tag. This needs a distinct constructor shape in v1 (see Plan, Phase 1) —
recommend modeling voidness as a different smart-constructor pattern, not
as another `Category`.

### 1.7 Tooling available

- No external lake dependencies (`lake-manifest.json` → `packages: []`), so
  no Mathlib, no existing test framework.
- `#guard <expr>` (core Lean) is a zero-dependency, compile-time assertion:
  evaluates a decidable `Bool`/`Prop` expression, silently no-ops if true,
  **fails the build** with a clear message if false. Verified both
  directions. This is the recommended default mechanism for unit/regression
  tests — every render-output test can be a one-line `#guard`, checked on
  every `lake build`, no test runner needed.
- Core Lean's `String`/`List Char` lemma library is thin without Mathlib.
  Nontrivial proofs about escaping (see Plan, Phase 2) may be easier if
  `escape` is implemented as a structural fold over `List Char`/`Array
  Char` (inducts cleanly) rather than a chain of `String.replace` calls
  (few reusable lemmas, harder to reason about compositionally). Whether to
  add Mathlib purely to get better string lemmas is an open call to make
  when that proof is actually attempted — don't decide it speculatively.
  Given this is the single highest-uncertainty item in the plan, do a
  throwaway spike of the proof early (Phase 0/1, before committing to the
  phase order below) rather than discovering mid-Phase-2 that core Lean is
  too thin — finding that out late means retrofitting a dependency after
  other phases have already assumed zero deps.
- `#guard_msgs` (core Lean) asserts on expected elaboration
  errors/messages — likely sufficient for Phase 4's "should fail to
  typecheck" regression cases without inventing a separate negative-compile
  CI mechanism. Check this before treating that as an open question.

### 1.8 `Coe String (Option String)` to avoid `some`-noise at attribute call sites (post-v1 ergonomics pass)

Every optional attribute field (`HtmlAttrs`, `AAttrs`, `InputAttrs`,
`HtmxAttrs`'s 17 fields, ...) is `Option String := none`, so setting one in
a struct literal required `some` at every call site
(`{ id := some "x", class_ := some "y" }`). Spiked and adopted: a `scoped
instance : Coe String (Option String) := ⟨some⟩` inside `namespace
Html`/`namespace Htmx` (`Html/Attrs.lean`, `Htmx/Attrs.lean`) lets `{ id :=
"x" }` elaborate directly, both in a bare struct literal and through a real
tag call's named default argument (`div [] (attrs := { id := "x" })`).
Confirmed empirically working transitively via `import Html`/`import
Htmx.Attrs` in files that never `open` those namespaces (e.g.
`Htmx/Tags.lean`, which uses qualified `Html.HtmlAttrs` literals) — the
exact activation rule wasn't nailed down further since the build is the
ground truth here, not the theory.

**Not a repeat of 1.2's coercion-insertion friction**, and worth stating
precisely why: 1.2 broke because the `Coe` shared a type variable between
source and target that was still an unresolved metavariable when Lean
compared the isolated-elaborated argument against the expected type
(`Node .phrasing ?m` vs. `Node .flow HtmxAttrs`). `Option String` is fully
concrete on both sides here, so there's no metavariable for coercion
insertion to choke on. Confirmed by spiking a deliberately wrong-typed
field (`{ id := true }`): the error is a plain, direct "Type mismatch: true
has type Bool but is expected to have type Option String", not 1.2's opaque
`Application type mismatch: ... ?m.7`. Added as a `#guard_msgs` regression
test (`Html/Attrs.lean`) so this doesn't silently regress back to 1.2-style
opacity if the mechanism ever changes.

**Rejected the same treatment for `HxSwap` (`hxSwap : Option HxSwap`) after
spiking it** — a real, different failure mode, not a variant of 1.2's:
leading-dot notation (`hxSwap := .outerHTML`) resolves its identifier
against the *expected* type's namespace directly (`Option`, looking for
`Option.outerHTML`) and never falls back to try a coercion source's
namespace, so `Coe HxSwap (Option HxSwap)` doesn't fire for the common case
at all — confirmed by the exact "Unknown constant `Option.outerHTML`"
error. Worse: because `HxSwap` happens to have its own `none` constructor,
the one case that *does* typecheck (`hxSwap := .none`) silently resolves to
`Option.none` (attribute absent) instead of `some HxSwap.none` (renders
`hx-swap="none"`) — a silent-wrong-behavior footgun with no matching
ergonomic upside. Reverted; `hxSwap` keeps `some .outerHTML`/`some .none`
explicit, documented in `Htmx/Attrs.lean` next to the instance list so it
isn't rediscovered by surprise. **Takeaway for any future `Option Enum`
field**: this `Coe` trick is safe for literal-syntax types (`String`,
`Bool` via `true`/`false`, presumably `Nat`/numerals) but not for types
whose values are conventionally written via leading-dot notation.

`scoped` (rather than a bare top-level instance) was a deliberate choice to
keep blast radius down — it only searches when resolving against a type
that routes through `Html`/`Htmx`, rather than making *every* `Option
String` anywhere accept a bare `String` silently.

### Phase 0 — Scoping decisions (do first, needs a decision each)
- [x] Confirm/trim the v1 element list. **Decision: accept the proposed
      starting set as-is** (structure: `html`, `head`, `body`, `div`,
      `section`, `article`, `header`, `footer`, `nav`; text: `p`, `span`,
      `h1`–`h6`, `ul`, `ol`, `li`, `blockquote`, `pre`, `code`; inline: `a`,
      `strong`, `em`, `small`, `br` [void]; forms: `form`, `input` [void],
      `label`, `textarea`, `select`, `option`, `button`; media/void: `img`
      [void], `hr` [void], `meta` [void], `link` [void]; table: `table`,
      `thead`, `tbody`, `tr`, `th`, `td`). No changes found necessary.
- [x] Confirm the v1 `Category` lattice. **Decision: `flow`/`phrasing`
      only, per the proven-ergonomic prototype; `metadata` is deferred.**
      `head`/`title`/`meta`/`link` are needed for Phase 5's document
      skeleton but are handled as a special case there (not general
      `metadata`-category content) rather than by generalizing the lattice
      now — full metadata-category fidelity is Phase 6 scope.
- [x] Decide file layout. **Decision: module tree from the start**
      (`Html/Node.lean`, `Html/Escape.lean`, `Html/Attrs.lean`,
      `Html/Tags.lean`, re-exported from `Html.lean`) — the v1 tag list
      above (~40 elements) already exceeds "comfortable in one file", so
      there's no single-file period worth having.
- [x] Add `[[lean_lib]] name = "Html"` to `lakefile.toml`. Done.
- [x] Decide `Node`'s internal representation (see 1.1). **Empirically
      spiked (compiled, not just reasoned about — see throwaway benchmark,
      not committed) before deciding, because the a priori reasoning
      turned out to be wrong:**
      - A flat, wide fan-out rendered via plain eager `String.join` (e.g. a
        160,000-row table, 13MB output) was fast — no quadratic blowup.
        Lean 4's runtime does optimize `acc ++ new` via in-place buffer
        growth when `acc` is uniquely owned, exactly as 1.1 hoped might be
        checked.
      - But naive **per-node** eager concatenation
        (`"<div>" ++ children ++ "</div>"`) *is* quadratic for **deep
        nesting**: a chain of 200,000 single-child wrapper `<div>`s took
        5.4s and scaled as O(depth²) (confirmed: 4× depth → ~15× time).
        Root cause: prepending the small open-tag onto already-large child
        content requires a full copy every level — Lean's in-place-append
        optimization only helps when new content is appended on the
        *right* of a uniquely-owned buffer, not when something is
        prepended on the *left*.
      - A "safe-looking" Hughes-list/difference-list builder
        (`String → String`, composed as `cat a b := fun k => a (b k)`) is
        **also quadratic**, for the identical reason: flattening a
        right-associated composition is prepend-shaped. Confirmed: 40,000
        rows took 11.8s and quadrupled with 2× input.
      - **The fix that is empirically linear:** an accumulator-threading
        builder where every primitive step *appends* onto one growing
        buffer, left-to-right, and never prepends — i.e. `Node` wraps a
        `String → String` function meaning "given what's built so far,
        return it with my content appended"
        (`cat a b := fun acc => b (a acc)`, `leaf s := fun acc => acc ++
        s`), with `render n := n.repr ""`. Confirmed linear up to a
        3.2M-deep chain (35MB, 0.69s) and a 320,000-row table (27MB,
        0.145s) — both cases that broke the other two representations at
        two orders of magnitude smaller scale.
      - **Takeaway for Phase 1:** direction of concatenation (append vs.
        prepend) matters far more on this runtime than "eager vs.
        deferred" as originally framed in 1.1. Implement `Node`'s smart
        constructors directly in this append-only accumulator style; do
        not write `open ++ children ++ close` anywhere.
- [x] Confirm `<script>`/`<style>` are out of v1 scope. **Confirmed, for
      the stated reason**: they are raw-text elements needing JS/CSS
      escaping, not HTML entity escaping; Phase 2's generic child-escaping
      would silently mis-escape their content. Documented here as a
      remembered exclusion, to be enforced again in Phase 4/5 module docs.
- [x] Spike-attempt the Phase 2 escaping proof on a throwaway basis (see
      1.7), to de-risk the Mathlib-or-not call. **Done — full success,
      zero Mathlib, zero `sorry`.** Proved, in core Lean only: `escape`
      (implemented as `String.join (s.toList.map escapeChar)`, a
      structural fold over `List Char` per 1.7's recommendation) never
      produces a raw `<`, `>`, or `"` in its output, by induction over
      `List Char`/`List String`. **Decision: v1 stays at zero Lake
      dependencies; do not add Mathlib.** Real friction hit along the way,
      worth keeping as a template so Phase 2 doesn't rediscover it from
      scratch:
      - The safety predicate must be `Bool`-valued
        (`c == '<' || c == '>' || c == '"'`), not `Prop`-valued
        (`c = '<' ∨ ...`) — core Lean does not auto-synthesize
        `Decidable (∀ c ∈ l, P c)` for a `∨`/`=`-shaped `Prop`, and
        `decide` needs the predicate computable from the start.
      - `split` behaves differently on the goal vs. on an already-`intro`'d
        hypothesis derived from a `match` — splitting a hypothesis hit an
        opaque "Expected type must not contain free variables" error;
        splitting the goal before introducing bound variables avoided it.
      - `String.join`'s definition (`List.foldl (·++·) ""`) doesn't induct
        directly — needed a helper lemma with the accumulator
        **universally quantified** (`∀ acc, (l.foldl (·++·) acc).toList =
        acc.toList ++ (l.map toList).flatten`), proved by induction on the
        list.
      - Only `String.toList_singleton` is `@[simp]`; `String.toList_empty`
        and `String.toList_append` exist in core but are not simp-tagged —
        cite them explicitly.
      - Unpacking membership in a twice-mapped, then-flattened list
        (`c ∈ ((l.map f).map g).flatten`) via `List.mem_flatten`/
        `List.mem_map` needs one destructuring layer per `map` — easy to
        under-destructure and get a type mismatch (hit this once: got a
        `String` where a `Char` was expected).

### Phase 1 — Core node & content model
- [x] `Category` inductive, `Node (cat : Category)` with private
      constructor per the representation decided in Phase 0, `Coe (Node
      .phrasing) (Node .flow)`. Implemented in `Html/Node.lean`, exported
      via `Html.lean` per Phase 0's module-tree layout decision. `Node`
      wraps the append-only `String → String` accumulator from the Phase 0
      spike (`leaf`/`andThen`/`concatAll`, all private); `render` is the
      only place a `Node` becomes a `String`.
- [x] Void-element constructor shape (distinct from the children-taking
      shape) — implemented as `Node.element` (open tag, children, close
      tag) and `Node.voidElement` (open tag only, self-closing, no
      children param) — both generic helpers, not yet wired to real named
      tags (`div`, `br`, ...); that's Phase 4, once category constraints
      per element are worked out.
- [x] `#guard` tests: minimal render output for a normal element (nested
      and sibling cases), a void element, and one case exercising the
      `Coe (Node .phrasing) (Node .flow)` instance — see bottom of
      `Html/Node.lean`. No attributes yet, as planned; deferred to Phase
      3. Verified the guards actually catch a regression (deliberately
      broke one, confirmed `lake build` fails, restored). Also added
      `"Html"` to `lakefile.toml`'s `defaultTargets` — it was missing from
      Phase 0's setup, so these guards were silently skipped by a plain
      `lake build` until now (only `webapp`'s target was default; caught
      by checking job counts, not by assumption).

### Phase 2 — Escaping & attribute rendering
- [x] `escape` for text content and attribute values (single, carefully
      ordered function — `&` must be replaced first, or later replacements
      corrupt it; carry this ordering forward, it's a genuine correctness
      detail, not incidental). Implemented in `Html/Escape.lean` as a
      structural fold over `List Char` (`escapeChar` + `escape`), per
      1.7's recommendation and matching the Phase 0 spike.
- [x] **Proof**: `escape`'s output never contains a raw (unescaped) `<`,
      `>`, or `"` — `Html.escape_safe`. Reused the Phase 0 spike's proof
      structure directly (private `Bool`-valued `isDangerous` internally,
      for `decide`; public theorem stated in plain `Prop` equalities at
      the boundary). Zero Mathlib, zero `sorry` — verified with
      `#print axioms`, depends only on the standard core axioms
      (`propext`, `Classical.choice`, `Quot.sound`), no `sorryAx`.
- [x] **State as an explicit precondition of the above proof, and enforce
      it in the renderer**: `Html.renderAttr` always emits
      `name="escaped value"` with a hard-coded double quote — there is no
      codepath in this library that renders an attribute value unquoted or
      single-quoted. Documented on `renderAttr` itself as a load-bearing
      precondition of `escape_safe`'s guarantee, not a stylistic default.
- [x] **Proof**: `Html.escape_append` — `escape (a ++ b) = escape a ++
      escape b`, composing already-escaped fragments behaves the same as
      escaping the concatenation. Also zero Mathlib, zero `sorry`.
- [x] `#guard` tests per metacharacter and combinations (`<script>`,
      `"onclick="`, literal `&`, empty string, non-ASCII, all four
      metacharacters together, and a re-escaping case
      `escape "&amp;" = "&amp;amp;"` documenting that already-escaped
      input is not special-cased). Plus `renderAttr` guards. Verified the
      guards catch a regression the same way as Phase 1 (deliberately
      broke one, confirmed `lake build` fails, restored).

### Phase 3 — Attributes
- [x] `HtmlAttrs` (global: `id`, `class`; extended with `style`/`title`/
      `lang`/`dir` per Phase 0 scope). Implemented in `Html/Attrs.lean` as
      a plain structure of `Option String` fields, all defaulting to
      `none`; `class_` (trailing underscore — `class` is a Lean keyword)
      renders as `class`. Not yet wired into `Node`/tag functions — that's
      Phase 4.
- [x] Per-element typed attribute records: `AAttrs` (`<a>`, `href`
      required), `ImgAttrs` (`<img>`, `src` and `alt` both required),
      `InputAttrs` (`<input>`, `type` plus optional `name`/`value`/
      `placeholder` and the four boolean attributes below). Covers the
      three examples the plan names explicitly; more can be added in
      Phase 4 following the same pattern as each real tag is built.
- [x] Boolean attributes (`disabled`, `checked`, `required`, `readonly`):
      **decision — bare attribute name when `true`, absent entirely when
      `false`, never `name="false"`** — `Html.renderBoolAttr`, used by
      `InputAttrs.render`. `#guard`-tested both ways, including the
      `false` case explicitly (not just omitted).
- [x] URL-valued attributes (`href`, `src`): **decision — stay plain
      `String` for v1**, not a dedicated type. Documented as an explicit
      non-goal both on `AAttrs`/`ImgAttrs` in code and alongside the
      `rawAttrs`/`unsafeRaw` caveats in section 1.3 above (`escape_safe`
      defends against markup breakout, not against a `javascript:`-scheme
      value).
- [x] `renderRawAttrs : List (String × String) → String` (the primitive
      Phase 4's tags will each take as `rawAttrs := []`). **Decision: the
      name half is not validated** — values are escaped, names are
      assumed to always be literal source-code identifiers per 1.3 (now
      updated with this assumption stated explicitly, next to the
      "value-escaped, name unchecked" description).
- [x] `#guard` tests per attribute (`HtmlAttrs`, `AAttrs`, `ImgAttrs`,
      `InputAttrs`, `renderBoolAttr`), plus one test on `renderRawAttrs`
      documenting — not fixing — that a space in an attribute name breaks
      out of the tag (`("evil onmouseover=\"alert(1)", "x")` renders as
      literal, structurally-breaking output). Verified the guards catch a
      regression the same way as Phases 1–2 (deliberately broke one,
      confirmed `lake build` fails, restored).

### Phase 4 — Tags
- [x] Implement each tag from the Phase 0 list with correct
      `Category`/children constraints, in `Html/Tags.lean` (39 tags).
      Required extending `Html/Node.lean`'s primitives first: `element`
      assumed the element's own category equals its children's category,
      which is wrong for `p`/`h1`–`h6`/`pre` (flow elements that only
      accept phrasing children — a `<div>` inside a `<p>` must be a type
      error). Added `elementOf (cat contentCat : Category) ...` for the
      cross-category case (`element` is now defined in terms of it, for
      the common same-category case); added `textElement` for `<textarea>`
      /`<option>` (RCDATA-like: entities escaped normally, but content is
      plain text, not nested elements — typing it as `List (Node cat)`
      would have been misleading); added `text : String → Node cat` (an
      escaped-text leaf, needed for any real content — e.g.
      `p [text "hi"]` — and not explicitly called out earlier in the plan,
      but required for the library to be usable); added `attrsStr`
      parameters throughout, threaded from Phase 3's `HtmlAttrs.render`/
      `renderRawAttrs`. `html`/`head`/`body`/`meta`/`link` deliberately
      **not** defined here — per Phase 0's category-lattice decision they
      belong to Phase 5's `Html.document` skeleton, not general tags.
      Element-specific attributes beyond `AAttrs`/`ImgAttrs`/`InputAttrs`
      (Phase 3) — `form`'s `action`, `button`'s `disabled`, `select`'s
      `multiple`, etc. — are not modeled as typed fields (documented in
      `Html/Tags.lean`'s module doc; use `rawAttrs`). Container elements
      with a stricter real content model than flow/phrasing (`ul`/`ol`
      only `<li>`, `table`/`tr` only specific children, `select` only
      `<option>`) accept general flow/phrasing children — the same
      documented Phase 0 simplification as everywhere else, not a new gap.
- [x] `unsafeRaw : String → Node cat` — added to `Html/Node.lean` (needs
      the private constructor, so can't live in `Tags.lean`).
- [x] `#guard` smoke test per tag (39 tags), plus composition tests
      (nesting, phrasing-into-flow coercion, `text`, `unsafeRaw`, `attrs`,
      `rawAttrs` all working together). **`#guard_msgs` confirmed to work**
      for "should fail to typecheck" regression documentation — added one
      for `p` rejecting a nested `div` (the plan's own example), checked
      it fails correctly both on message-text drift and on an actual
      type-safety regression (temporarily made `p` accept flow children;
      confirmed `#guard_msgs` caught it because the example stopped
      erroring at all — not just a text mismatch — then restored). No
      separate negative-compile CI mechanism needed.

### Phase 5 — Integration & docs
- [x] `Html.document`: assembles `<!DOCTYPE html>` plus the
      `<html>`/`<head>`/`<body>` skeleton, in a new `Html/Document.lean`
      (a natural addition to Phase 0's module tree, not anticipated by
      name there but following its "split when it grows" principle).
      Built entirely from `Node`'s existing *public* API
      (`element`/`voidElement`/`textElement`) rather than hand-rolled
      string concatenation — `head`/`html`/`body`/`meta`/`title`/`link`
      don't need `Node`'s private constructor, and reusing `Node.element`
      for `body` specifically avoids reintroducing the Phase 0 quadratic-
      prepend trap for what could be large page content (the single
      top-level `"<!DOCTYPE html>" ++ render htmlNode` prepend is a
      one-time, non-repeated cost, unlike the nested-per-level case that
      was actually quadratic). Always emits `<meta charset="utf-8">`;
      takes optional extra `metaTags`, `stylesheets`, and `lang`.
      `#guard`-tested, including that the title is escaped.
- [x] Wired into `Main.lean`'s `Std.Http.Server` handler: builds a real
      page (`h1`/`p`/`strong`/`Node.text`) via `Html.document`, served via
      `Response.ok |>.html page` (found `Response.Builder.html` in
      `Std.Http.Data.Body.Full` — sets `Content-Type: text/html;
      charset=utf-8` automatically, better than the generic `.text`).
      Verified end-to-end for real, not just by building: ran the server,
      `curl`'d it, confirmed `Content-Type: text/html; charset=utf-8` and
      correctly-nested, correctly-escaped HTML in the response body.
- [x] Module docs — added to `Html.lean` (the natural entry point):
      design overview (one phantom `Category` parameter, why attributes
      aren't a second one, content-model-correctness as a corollary of
      type soundness), the two escape hatches (`rawAttrs`, `unsafeRaw`)
      with their safety caveats, and step-by-step "how to add a new
      tag"/"how to add a new attribute" sections referencing the concrete
      patterns established in Phases 3–4.

### Phase 6 — Deferred (explicitly out of scope this phase)
- [x] `Htmx` library — design already validated (1.4): typed wrapper tags
      over `rawAttrs`, zero changes needed to `Html`. **Implemented** as its
      own `lean_lib` (`Htmx.lean`, `Htmx/Attrs.lean`, `Htmx/Tags.lean`,
      added to `lakefile.toml`'s `defaultTargets`), depending on `Html` in
      one direction only. `HtmxAttrs` (`Htmx/Attrs.lean`) is a fixed
      structure of `Option _` fields for the common `hx-*` attributes
      (`hxGet`/`hxPost`/.../`hxDelete`, `hxTrigger`, `hxTarget`, `hxSwapOob`,
      `hxSelect`/`hxSelectOob`, `hxPushUrl`, `hxConfirm`, `hxIndicator`,
      `hxVals`, `hxExt`, `hxParams`), plus a real closed `HxSwap` enum for
      `hx-swap` (the concrete example 1.4 named — `hxSwap := some "banana"`
      is now a compile error) and `hxBoost : Option Bool` (htmx only accepts
      literal `true`/`false` there, unlike `hxPushUrl`, which can also be a
      URL and so stays `String`). `HtmxAttrs.toPairs` flattens to
      `List (String × String)` of *unescaped* values — escaping happens
      once, at render time, in `Html.renderRawAttrs`, exactly like every
      other `rawAttrs` caller; this library does not duplicate that logic.
      `Htmx/Tags.lean` has one wrapper per `Html/Tags.lean` tag (div through
      td), each with the *same* signature as the matching `Html.*` function
      plus one extra `hx : HtmxAttrs := {}` parameter positioned right
      before `attrs`, forwarding via `hx.toPairs ++ rawAttrs` — confirmed
      `Html.lean` needed zero changes (no edits made to any `Html/*.lean`
      file for this phase). `#guard` smoke tests per wrapper tag, plus
      composition tests confirming an `Htmx.div` nests inside a plain
      `Html.div` and vice versa with no coercion needed (an `Htmx.*` tag's
      result is a plain `Html.Node`, per 1.4's accepted tradeoff: no
      whole-page "this uses htmx" static guarantee). Verified end-to-end,
      not just by building: wired `Htmx.button` (with `hxGet`/`hxTarget`/
      `hxSwap`) into `Main.lean`'s page next to plain `Html` tags, ran the
      server, `curl`'d it, confirmed `hx-get="/ping" hx-target="#result"
      hx-swap="innerHTML"` rendered correctly in the response body. (A
      working `/ping` route to actually handle the click is out of scope
      here — routing itself is a separate, not-yet-built design; see
      `docs/routing-design-plan.md`.)
- [ ] Broader `Category` lattice / transparent content model fidelity.
- [x] **Pretty-printed (indented) output mode.** Implemented:
      `Node.renderPretty`, plus `Html.document` gained `pretty := false` and
      `unit := "  "` parameters rather than a separate `documentPretty`
      function (kept it one entry point instead of two near-duplicate ones
      -- `document`'s existing default arguments made this a natural fit).
      `render`/`document`'s compact output is unchanged (`pretty`'s default
      is `false`). Required
      a real representation change, not a cosmetic addition: `Node` was
      *only* an append-only `String → String` accumulator (1.1/Phase 0),
      which renders fast but throws away tree shape the moment a node is
      built — nothing left to know where a newline or indent level should
      go. Replaced it with a private tree (`Repr`: `leaf`/`void`/`rawText`/
      `elem`), and rewrote both `render` and `renderPretty` as direct
      recursive walks over that tree using the *same* append-only
      accumulator-threading discipline the Phase 0 spike found to be
      linear (always `acc ++ smallPiece`, never prepend) — confirmed this
      doesn't reintroduce the quadratic trap by re-running Phase 0-style
      throwaway benchmarks (not committed): compact rendering of a
      2,000,000-deep chain and a 2,000,000-row flat table both still
      complete in well under a millisecond, unchanged from before the
      representation swap.
      - **Layout decision, reusing machinery that already existed**:
        `elementOf`'s existing `contentCat` argument (the category of an
        element's *children*, already tracked separately from the
        element's own category to make e.g. `<div>` illegal inside `<p>` a
        type error) doubles as the pretty-printer's layout signal for
        free. `contentCat = .flow` → block layout, each child on its own
        indented line (matches HTML5 flow content generally being
        block-level, where inserted whitespace between siblings is
        invisible). `contentCat = .phrasing` → inline layout, rendered
        identically to compact (no added whitespace at any depth) —
        load-bearing, not cosmetic: whitespace between text/inline runs
        *is* visible in rendered HTML (`<span>a</span><span>b</span>` vs.
        with an inserted separator), so the pretty-printer must never
        inject any there. This is also what keeps `pre`'s content
        untouched (`pre`'s children are typed `phrasing`, so inline layout
        applies automatically — no special-casing needed) and, separately,
        `textarea`/`option` content is never touched regardless of layout
        because `textElement` stores raw content as an opaque leaf
        (`rawText`), never recursed into by the pretty-printer at all.
      - **Secondary layout rule**: a `block`-layout element with zero
        children, or with exactly one *leaf* (bare text/`unsafeRaw`)
        child, stays on one line (`<li>one</li>`, not `<li>\n  one\n</li>`)
        — anything else (multiple children, or a single non-leaf/void
        child) gets one-child-per-line. `#guard`-tested both ways.
      - **Known, accepted, non-bug limitation**: indented output for a
        chain of `D` nested block elements is `O(D²)` *characters*, hence
        `O(D²)` time — not a reintroduction of the Phase 0 prepend trap,
        but the unavoidable minimum, since the output itself is `O(D²)`
        (line `d` carries `O(d)` leading spaces, summed `1..D`). Confirmed
        empirically: doubling depth from 6,000 to 12,000 quadrupled output
        size (72M → 288M chars) as predicted; 40,000-deep pretty-printed
        output OOM'd, which is expected output-size growth, not an
        algorithmic bug — compact rendering of the same depth is unaffected
        (still linear, still fast). Documented on `Node.renderPretty` and
        `Html.document`'s `pretty` parameter as a debug/human-readability
        tool, not a replacement for compact output on any size-sensitive
        path.
- [ ] XHTML target — considered and set aside (HTML5 semantics were judged
      more useful; XHTML5 shares HTML5's content model exactly so buys
      nothing, and XHTML 1.x's cleaner DTD-based grammar targets a
      effectively dead format).
- [x] **Full HTML5 element-set pass (2026-07-14).** Added every remaining
      ordinary WHATWG HTML Living Standard element not in Phase 0's
      original ~40 — text-level semantics (`i`/`b`/`u`/`s`/`mark`/`cite`/
      `dfn`/`abbr`/`var`/`samp`/`kbd`/`sub`/`sup`/`bdi`/`bdo`/`ruby`/`rt`/
      `rp`/`wbr`/`q`/`time`/`data`), sectioning/grouping (`aside`/`hgroup`/
      `address`/`main`/`figure`/`figcaption`/`dl`/`dt`/`dd`/`menu`/
      `search`), tabular (`caption`/`colgroup`/`col`/`tfoot`), forms
      (`fieldset`/`legend`/`datalist`/`optgroup`/`output`/`progress`/
      `meter`), interactive (`details`/`summary`/`dialog`), scripting/
      metadata (`base`/`noscript`/`template`/`canvas`/`slot`), and embedded
      content (`picture`/`source`/`track`/`iframe`/`embed`/`object`/
      `video`/`audio`/`map`/`area`) — all in `Html/Tags.lean`, following
      Phase 4's exact pattern (`Node.element`/`.elementOf`/`.voidElement` +
      `combineAttrs`, one `#guard` smoke test per tag). Extended
      `Html/Attrs.lean` with a typed `XAttrs` record for every element with
      real element-specific attributes (not just globals) — ~20 new
      records, same shape as `AAttrs`/`ImgAttrs`/`InputAttrs`, value-typed
      fields staying plain `String` per 1.3 (no new numeric/URL types).
      **Deliberately stayed within the existing flow/phrasing lattice** —
      this item's own "broader Category lattice" checkbox stays unchecked;
      this pass fills out the tag list, it doesn't add new categories.
      **One real exception**: `ins`/`del` gained genuine category
      polymorphism (`cat` left as a free, auto-bound implicit — the same
      trick `Node.text`/`Node.unsafeRaw` already used) instead of a fixed
      `.flow`/`.phrasing` choice, giving them real "whatever my parent
      allows" transparent-content behavior within the 2-category lattice,
      confirmed working both ways with a `#guard` composition test (inside
      a `<p>` and inside a `<div>`, no manual type ascription needed
      either way) — see `Html/Tags.lean`'s composition-tests section.
      `<a>` has the same transparent-model property in the real spec but
      was already implemented fixed-`.phrasing` in Phase 4; left as-is
      here (out of this pass's scope). **Explicitly excluded**: SVG/MathML
      (foreign-namespace content needs its own design decision, plausibly
      its own `lean_lib` mirroring `Htmx` — not a same-shape tag addition)
      and an inline-content `<style>` tag / inline-content `<script>`
      variant (both stay excluded per Phase 0's original reasoning: raw-
      text elements needing JS/CSS escaping, not HTML entity escaping —
      `Html.script`'s existing external-`src` form is unaffected). Two new
      keyword-clash renames, same convention as `class_`/`section_`:
      `for_` (`<output>`'s `for` attribute) and `open_` (`<details>`/
      `<dialog>`'s `open` attribute, sharing one `OpenAttrs` record since
      both elements have the exact same single boolean field).

## 3. Test & proof strategy, summarized

- Default mechanism: `#guard <decidable-expr>` for every render-output
  example (tag shapes, attributes, escaping cases). Zero dependencies,
  enforced on every `lake build`.
- Reserve actual `theorem ... := by ...` proofs for universal properties
  not already implied by typing — chiefly Phase 2's escaping-safety lemma
  and its compositionality corollary (fragment concatenation doesn't
  double- or under-escape at the seam).
- The escaping-safety proof rests on an explicit renderer invariant:
  attribute values are always double-quote-delimited, never unquoted or
  single-quoted. State it, don't let it be an implicit assumption.
- Content-model correctness and tag-balance (every open tag's matching
  close is emitted by the same smart-constructor call) need no separate
  proof — both are implied by type soundness / construction of a
  well-typed `Node`-building program, by the same argument as 1.1.
- Anything passed through `rawAttrs`/`unsafeRaw` is explicitly out of scope
  for any proof — document this boundary, don't let it get blurred later.
  This includes `rawAttrs`' attribute *names* specifically (only values are
  escaped) and URL-valued attributes (`href`/`src`) if they stay untyped
  `String` — generic escaping doesn't defend against a `javascript:`-scheme
  value.
