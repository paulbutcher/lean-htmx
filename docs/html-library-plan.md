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

## 2. Implementation plan (v1: html only, no htmx)

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
- [ ] `escape` for text content and attribute values (single, carefully
      ordered function — `&` must be replaced first, or later replacements
      corrupt it; carry this ordering forward, it's a genuine correctness
      detail, not incidental).
- [ ] **Proof**: `escape`'s output never contains a raw (unescaped) `<`,
      `>`, or `"`. This is the actual XSS-relevant safety property and the
      main piece of formal verification worth doing for v1. Decide
      representation (see 1.7) as part of this task.
- [ ] **State as an explicit precondition of the above proof, and enforce
      it in the renderer**: attribute values are *always* rendered
      double-quote-delimited — the renderer never emits unquoted or
      single-quoted attribute syntax. HTML5 permits unquoted attribute
      values; if the renderer ever emitted one, escaping only `<`/`>`/`"`
      stops being sufficient (a bare space or `>` breaks out of an unquoted
      value) and the proof's guarantee silently stops applying to that
      codepath. Pin this down now so it isn't rediscovered by surprise if
      someone adds unquoted rendering later.
- [ ] **Proof or explicit argument**: composing already-escaped fragments
      (`escape a ++ escape b`) behaves the same as escaping the
      concatenation in context — i.e. no double-escaping and no
      under-escaping at fragment boundaries. This is the formal version of
      the "`&` must go first" ordering note above; worth a lemma rather
      than leaving the ordering constraint as a comment.
- [ ] `#guard` tests per metacharacter and combinations (`<script>`,
      `"onclick="`, literal `&`, empty string, non-ASCII).

### Phase 3 — Attributes
- [ ] `HtmlAttrs` (global: `id`, `class`; extend with `style`/`title`/
      `lang`/`dir` per Phase 0 scope).
- [ ] Per-element typed attribute records where the element has
      required/typed attributes of its own (`AAttrs` for `<a>`, similarly
      for `<img>`, `<input>`, etc., per Phase 0 scope).
- [ ] Decide how boolean attributes (`disabled`, `checked`, `required`,
      `readonly`) render — bare attribute name when present, absent
      entirely when not, never `name="false"`. Not a corollary of anything
      else in the plan; needs its own explicit decision and `#guard` test.
- [ ] Decide whether URL-valued attributes (`href`, `src`) get a dedicated
      type, or stay plain `String`. Generic escaping (Phase 2) defends
      against markup breakout but not against a `javascript:`-scheme value
      — a distinct, well-known injection vector. If staying `String` for
      v1, document this as an explicit non-goal alongside the
      `rawAttrs`/`unsafeRaw` caveats, not a silent gap.
- [ ] `rawAttrs : List (String × String) := []` on every tag. Decide
      whether the *name* half gets any validation: the plan so far only
      escapes the *value*; an attribute name containing a space, `=`, or
      `>` breaks out of the tag regardless of value-escaping. If names are
      always literal source-code identifiers in practice, document that
      assumption explicitly next to the "value-escaped, name unchecked"
      description in 1.3 rather than leaving the asymmetry unstated.
- [ ] `#guard` tests per attribute; one test documenting (not fixing) that
      `rawAttrs` is intentionally unchecked.

### Phase 4 — Tags
- [ ] Implement each tag from the Phase 0 list with correct
      `Category`/children constraints.
- [ ] `unsafeRaw : String → Node cat`.
- [ ] `#guard` smoke test per tag. Keep the prototype's "should fail to
      typecheck" comments as living regression documentation (e.g. `p`
      rejecting a nested `div`); check whether core Lean's `#guard_msgs`
      (see 1.7) can enforce these as real negative-compile regression tests
      rather than comments before reaching for separate CI tooling.

### Phase 5 — Integration & docs
- [ ] `Html.document` (or similar): assembles `<!DOCTYPE html>` plus the
      `<html>`/`<head>`/`<body>` skeleton into one entry point. Nothing
      earlier in the plan produces a full page — Phases 1–4 only build
      tags and the `render : Node cat → String` primitive: this is the
      missing top-level piece that turns a `Node` into a servable document.
- [ ] Wire a rendered page into `Main.lean`'s `Std.Http.Server` handler
      (currently `Response.ok |>.text "Hey there ;-)"`) as an end-to-end
      smoke test that the library serves real output.
- [ ] Module docs: design overview, the two escape hatches and their
      safety caveats, how to add a new tag/attribute.

### Phase 6 — Deferred (explicitly out of scope this phase)
- [ ] `Htmx` library — design already validated (1.4): typed wrapper tags
      over `rawAttrs`, zero changes needed to `Html`.
- [ ] Broader `Category` lattice / transparent content model fidelity.
- [ ] Pretty-printed (indented) output mode.
- [ ] XHTML target — considered and set aside (HTML5 semantics were judged
      more useful; XHTML5 shares HTML5's content model exactly so buys
      nothing, and XHTML 1.x's cleaner DTD-based grammar targets a
      effectively dead format).

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
