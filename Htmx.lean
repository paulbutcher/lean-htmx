import Html
import Htmx.Attrs
import Htmx.Tags

/-!
# `Htmx`: typed htmx attributes on top of `Html`

A separate Lake `lean_lib`, built entirely on `Html`'s public API. See
`docs/html-library-plan.md` 1.4 for the design rationale (worked out and
validated by prototype while designing `Html` itself, then deferred to
Phase 6) and the Phase 6 entry for what shipped.

## Why a separate library, and what it does/doesn't guarantee

`Html.Node` deliberately has exactly one phantom type parameter
(`Category`, not also an attribute-vocabulary index) -- see `Html.lean`'s
module doc and `docs/html-library-plan.md` 1.2 for why: making the
attribute vocabulary part of `Node`'s type broke Lean's coercion-insertion
ergonomics badly enough to produce unreadable errors on ordinary code. This
library gets full type safety for `hx-*` attributes *without* reopening
that problem, using a different mechanism than "index `Node` by dialect":

- `HtmxAttrs` (`Htmx/Attrs.lean`) is one fixed, concrete structure -- fields
  for the common `hx-*` attributes, `Option _ := none`, plus a real closed
  `HxSwap` enum for `hx-swap` (rejects `hxSwap := some "banana"` at compile
  time, unlike a bare `String` field would). It `extends Html.HtmlAttrs`,
  mirroring `Html`'s own per-element attrs pattern (`AAttrs extends
  HtmlAttrs`, etc.), so it doubles as the single merged attrs type for
  every tag that otherwise takes plain `HtmlAttrs`. Elements with their own
  `Html.<Tag>Attrs` (`OlAttrs`, `FormAttrs`, `ImgAttrs`, ...) get a matching
  `Htmx.<Tag>Attrs extends Html.<Tag>Attrs, HtmxAttrs` -- Lean's structure
  inheritance shares the `Html.HtmlAttrs` fields both sides inherit rather
  than duplicating them, so this is a two-line declaration per element (see
  `Htmx/Attrs.lean`'s block of them), not a repeat of all 19 `hx-*` fields.
- Every tag here (`Htmx/Tags.lean`) is a thin wrapper with *exactly* the
  same signature as the matching `Html.*` tag -- a single `attrs` argument
  plus `rawAttrs`, nothing extra. Internally it validates nothing beyond
  what the attrs type's own fields already enforce, splits `attrs` back
  into its `Html.<Tag>Attrs` part (via the auto-generated `to<Tag>Attrs`/
  `toHtmlAttrs` projection) and its `HtmxAttrs` part (via `toHtmxAttrs`,
  flattened by `HtmxAttrs.toPairs`), and forwards to the matching `Html.*`
  function via its existing `rawAttrs` parameter -- exactly `Html`'s
  "escape hatch for what the typed vocabulary doesn't cover" mechanism
  (`docs/html-library-plan.md` 1.3), just filled in by this library's own
  typed values instead of ad hoc call-site pairs. `Html.lean` needed
  **zero** changes.

Accepted tradeoff, carried over unchanged from 1.4: an `Htmx.div`'s result
is a plain `Html.Node .flow`, identical to and freely composable with
whatever `Html.div` produces -- there is no whole-page "this document
does/doesn't use htmx" static guarantee. Nothing stops htmx-typed content
from ending up in a tree with no other htmx usage, or vice versa. That
guarantee is exactly what 1.2's rejected design would have given, and is
exactly what cost the ergonomics there; this library does not attempt it.

## How to add a new `hx-*` attribute

Add a field to `HtmxAttrs` in `Htmx/Attrs.lean` (a closed vocabulary like
`hx-swap`'s gets its own enum, per `HxSwap`'s pattern; most attributes stay
plain `Option String`, same non-goal as `Html`'s `href`/`src` -- see 1.3),
wire it into `HtmxAttrs.toPairs`, and add a `#guard` test to
`Tests/Attrs.lean`. Every per-element `Htmx.<Tag>Attrs` picks it up
automatically, since they all extend `HtmxAttrs`.

## How to add a new htmx-wrapped tag

Add a wrapper to `Htmx/Tags.lean` with exactly the same signature as the
matching `Html.*` tag -- if that tag takes plain `Html.HtmlAttrs`, use
`HtmxAttrs` as `attrs`; if it takes its own `Html.<Tag>Attrs`, first add
`structure Htmx.<Tag>Attrs extends Html.<Tag>Attrs, HtmxAttrs` next to the
others in `Htmx/Attrs.lean`, then use that as `attrs`. Forward via
`attrs.to<Tag>Attrs`/`attrs.toHtmlAttrs` for the `Html.*` call's own attrs
argument and `attrs.toHtmxAttrs.toPairs ++ rawAttrs` (or just
`attrs.toPairs ++ rawAttrs` for the plain-`HtmxAttrs` case) for its
`rawAttrs` -- see any existing wrapper (e.g. `Htmx.div`, `Htmx.form`) for
the exact shape. Add a `#guard` smoke test to `Tests/Tags.lean`, next to
the others.
-/
