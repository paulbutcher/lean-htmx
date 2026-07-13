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
  time, unlike a bare `String` field would).
- Every tag here (`Htmx/Tags.lean`) is a thin wrapper with the *same*
  signature as the matching `Html.*` tag, plus one extra typed
  `hx : HtmxAttrs := {}` parameter. Internally it validates nothing beyond
  what `HtmxAttrs`'s own field types already enforce, flattens `hx` via
  `HtmxAttrs.toPairs`, and forwards to the matching `Html.*` function via
  its existing `rawAttrs` parameter -- exactly `Html`'s "escape hatch for
  what the typed vocabulary doesn't cover" mechanism (`docs/html-library-plan.md`
  1.3), just filled in by this library's own typed values instead of ad hoc
  call-site pairs. `Html.lean` needed **zero** changes.

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
wire it into `HtmxAttrs.toPairs`, and add a `#guard` test.

## How to add a new htmx-wrapped tag

Add a wrapper to `Htmx/Tags.lean` with the same signature as the matching
`Html.*` tag plus `(hx : HtmxAttrs := {})`, forwarding via
`hx.toPairs ++ rawAttrs` -- see any existing wrapper (e.g. `Htmx.div`) for
the exact shape. Add a `#guard` smoke test next to the others.
-/
