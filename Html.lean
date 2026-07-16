import Html.Node
import Html.Escape
import Html.Attrs
import Html.Tags
import Html.Document

/-!
# `Html`: a typed HTML5 library

Renders well-formed, escaped HTML from Lean values, using Lean's type
system to make illegal nesting unrepresentable. See
`docs/html-library-plan.md` for the full design rationale and phase
history; this is a short orientation for someone reading the code.

## Design overview

`Node (cat : Category)` (`Html/Node.lean`) is a private-constructor
wrapper around a small internal tree (`Repr`), indexed by the HTML
content-model category it's valid in. Only `flow` and `phrasing` are
modeled (v1 scope decision, `docs/html-library-plan.md` Phase 0); a
`Coe (Node .phrasing) (Node .flow)` instance lets phrasing content (`span`,
`a`, `strong`, ...) appear directly among a flow element's children. Every
tag function (`Html/Tags.lean`) is a smart constructor built from `Node`'s
public primitives (`element`, `elementOf`, `voidElement`, `textElement`,
`text`), so a well-typed program that builds a `Node` already has correct
tag nesting and balanced tags -- that's a corollary of type soundness, not
something checked separately at render time.

`render`/`document` produce compact output; `Node.renderPretty` and
`document`'s `pretty := true` (with a configurable `unit` indent string)
(Phase 6) produce indented output for debugging/reading, sharing the same
tree and the same append-only accumulator-threading walk (never prepend --
see `docs/html-library-plan.md` Phase 0/6) so compact rendering stays
linear even at millions of nodes. Layout reuses `elementOf`'s existing
`contentCat`: `flow` children lay out one per line, `phrasing` children
stay inline with no added whitespace (load-bearing, not cosmetic --
whitespace between text/inline runs is visible in rendered HTML), which is
also why `pre` and `textarea`/`option` content is never touched by the
pretty-printer. `renderPretty` is `O(D²)` for a `D`-deep chain of block
elements -- an accepted, documented limitation (the *output* is `O(D²)`
characters, not an algorithmic inefficiency); `render` is unaffected.

`Node` has exactly **one** phantom type parameter (`Category`), not two.
An earlier design also made the *attribute vocabulary* a type parameter,
to statically distinguish "plain HTML" from "HTML + htmx" pages -- it was
reverted because it broke Lean's coercion-insertion ergonomics badly
enough to produce unreadable errors on ordinary code (`docs/html-library-plan.md`
1.2). `HtmlAttrs` (`Html/Attrs.lean`) is one fixed, concrete structure
instead. A downstream library (htmx or similar) can still get full type
safety for its *own* attributes without this problem -- see 1.4 for the
mechanism (thin wrapper tags forwarding through `rawAttrs`, zero changes
needed to this library).

Attribute values and text content are escaped by `Html/Escape.lean`'s
`escape`, which is proved (`escape_safe`, no Mathlib, no `sorry`) to never
emit a raw `<`, `>`, or `"`. That guarantee depends on attribute values
always being double-quote-delimited (`renderAttr` enforces this
unconditionally) -- HTML5 permits unquoted attribute values, and the proof
would not cover that codepath if the renderer ever emitted one.

## The two escape hatches, and their safety caveats

Everything above is type-checked and (for escaping) proved safe. Two
deliberate, purely additive escape hatches exist for what the typed
vocabulary doesn't cover, and neither is type-checked or covered by any
proof in this library:

- **`rawAttrs : List (String × String) := []`**, present on every tag.
  Arbitrary `(name, value)` pairs rendered verbatim. *Values* are escaped
  the same way as everything else; *names* are not validated at all -- an
  attribute name containing a space, `=`, or `>` breaks out of the tag
  regardless of value-escaping. Names are assumed to always be literal
  source-code identifiers, never derived from untrusted input (`Tests/Attrs.lean`'s
  `renderRawAttrs` `#guard` documents this gap rather than closing it).
- **`Node.unsafeRaw : String → Node cat`** (`Html/Node.lean`). Verbatim,
  unescaped markup, trusted as-is, valid in any category. Named loudly, not
  `raw` -- passing untrusted input to it is a genuine XSS hole, and that
  risk should be visible at every call site.

Also out of scope: `AAttrs.href`/`ImgAttrs.src` stay plain `String` for
v1, not a dedicated URL type -- `escape_safe` defends against markup
breakout, not against a `javascript:`-scheme value (`docs/html-library-plan.md`
1.3).

## How to add a new tag

1. Decide the tag's own `Category` and its children's `Category` (they
   can differ -- e.g. `p` is `flow` but only accepts `phrasing` children,
   which is exactly what makes a `<div>` inside a `<p>` a type error). See
   `Html/Node.lean`'s `element` (same category both sides) vs. `elementOf`
   (different categories) vs. `voidElement` (no children) vs.
   `textElement` (plain-text content, RCDATA-like elements such as
   `<textarea>`).
2. If the element needs attributes beyond the global `HtmlAttrs` (`id`,
   `class`, `style`, `title`, `lang`, `dir`), add a typed record to
   `Html/Attrs.lean` following `AAttrs`/`ImgAttrs`/`InputAttrs`'s pattern:
   required fields as plain (non-`Option`) fields, everything else
   `Option _ := none`, boolean attributes rendered via `renderBoolAttr`.
3. Define the tag function in `Html/Tags.lean`: `(children) (attrs :=
   {}) (rawAttrs := [])`, calling the right `Node` primitive from step 1
   with `combineAttrs <specific-attrs-rendered> attrs rawAttrs` as the
   attribute string.
4. Add a `#guard` smoke test (minimal render output) to `Tests/Tags.lean`,
   next to the other tags' tests.

## How to add a new attribute

Add a field to `HtmlAttrs` (global) or the relevant per-element record in
`Html/Attrs.lean`, wire it into that structure's `.render`, and add a
`#guard` test to `Tests/Attrs.lean`. Boolean attributes must go through
`renderBoolAttr` (bare name when `true`, absent when `false`, never
`name="false"`); string attributes go through `renderAttr` (escaped,
double-quote-delimited).
-/
