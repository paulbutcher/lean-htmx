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

## 2. Implementation plan (v1: html only, no htmx)

### Phase 0 — Scoping decisions (do first, needs a decision each)
- [ ] Confirm/trim the v1 element list. Proposed starting set: structure
      (`html`, `head`, `body`, `div`, `section`, `article`, `header`,
      `footer`, `nav`), text (`p`, `span`, `h1`–`h6`, `ul`, `ol`, `li`,
      `blockquote`, `pre`, `code`), inline (`a`, `strong`, `em`, `small`,
      `br` [void]), forms (`form`, `input` [void], `label`, `textarea`,
      `select`, `option`, `button`), media/void (`img` [void], `hr` [void],
      `meta` [void], `link` [void]), table (`table`, `thead`, `tbody`,
      `tr`, `th`, `td`).
- [ ] Confirm the v1 `Category` lattice: at minimum `flow`/`phrasing`
      (proven ergonomic); decide whether `metadata` (`head`, `meta`,
      `link`, `title`) is in scope now or deferred.
- [ ] Decide file layout: single `Html.lean` vs a module tree
      (`Html/Node.lean`, `Html/Escape.lean`, `Html/Attrs.lean`,
      `Html/Tags.lean`, re-exported from `Html.lean`). Recommend splitting
      once the tag count grows past what's comfortable in one file.
- [ ] Add `[[lean_lib]] name = "Html"` to `lakefile.toml`.

### Phase 1 — Core node & content model
- [ ] `Category` inductive, `Node (cat : Category)` with private
      constructor, `Coe (Node .phrasing) (Node .flow)`.
- [ ] Void-element constructor shape (distinct from the children-taking
      shape) — e.g. a `voidTag` helper used by `img`/`br`/`input`/etc.,
      rendering `<tag ...>` with no children and no closing tag.
- [ ] `#guard` tests: minimal and attributed render output for at least one
      tag of each shape (normal, void).

### Phase 2 — Escaping & attribute rendering
- [ ] `escape` for text content and attribute values (single, carefully
      ordered function — `&` must be replaced first, or later replacements
      corrupt it; carry this ordering forward, it's a genuine correctness
      detail, not incidental).
- [ ] **Proof**: `escape`'s output never contains a raw (unescaped) `<`,
      `>`, or `"`. This is the actual XSS-relevant safety property and the
      main piece of formal verification worth doing for v1. Decide
      representation (see 1.7) as part of this task.
- [ ] `#guard` tests per metacharacter and combinations (`<script>`,
      `"onclick="`, literal `&`, empty string, non-ASCII).

### Phase 3 — Attributes
- [ ] `HtmlAttrs` (global: `id`, `class`; extend with `style`/`title`/
      `lang`/`dir` per Phase 0 scope).
- [ ] Per-element typed attribute records where the element has
      required/typed attributes of its own (`AAttrs` for `<a>`, similarly
      for `<img>`, `<input>`, etc., per Phase 0 scope).
- [ ] `rawAttrs : List (String × String) := []` on every tag.
- [ ] `#guard` tests per attribute; one test documenting (not fixing) that
      `rawAttrs` is intentionally unchecked.

### Phase 4 — Tags
- [ ] Implement each tag from the Phase 0 list with correct
      `Category`/children constraints.
- [ ] `unsafeRaw : String → Node cat`.
- [ ] `#guard` smoke test per tag. Keep the prototype's "should fail to
      typecheck" comments as living regression documentation (e.g. `p`
      rejecting a nested `div`); consider whether the team wants these
      enforced by an actual negative-compile CI step rather than comments.

### Phase 5 — Integration & docs
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
  not already implied by typing — chiefly Phase 2's escaping-safety lemma.
- Content-model correctness needs no separate proof (implied by type
  soundness of a well-typed `Node`-building program).
- Anything passed through `rawAttrs`/`unsafeRaw` is explicitly out of scope
  for any proof — document this boundary, don't let it get blurred later.
