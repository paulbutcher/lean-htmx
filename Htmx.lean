/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

import Html
import Htmx.Attrs
import Htmx.Tags

/-!
# `Htmx`: typed htmx attributes on top of `Html`

Built entirely on `Html`'s public API, using its `rawAttrs` escape hatch as
the delivery mechanism for this library's own typed values.

## Design overview

`HtmxAttrs` (`Htmx/Attrs.lean`) is one fixed structure holding the common
`hx-*` attributes, with a closed `HxSwap` enum for `hx-swap` so that
`hxSwap := some "banana"` is rejected at compile time. It extends
`Html.HtmlAttrs`, so it doubles as the attrs type for every tag that
otherwise takes plain `Html.HtmlAttrs`; elements with their own
`Html.<Tag>Attrs` get a matching `Htmx.<Tag>Attrs extends Html.<Tag>Attrs,
HtmxAttrs`.

Every tag in `Htmx/Tags.lean` is a wrapper with exactly the same signature
as the matching `Html.*` tag. It splits `attrs` into its `Html.<Tag>Attrs`
part and its `HtmxAttrs` part, flattens the latter with
`HtmxAttrs.toPairs`, and forwards both to the `Html.*` function, the
flattened pairs going through that function's `rawAttrs` parameter.

The type safety here is over the attributes of a single element. An
`Htmx.div` produces a plain `Html.Node .flow`, indistinguishable from and
freely composable with what `Html.div` produces, so there is no
whole-document guarantee that a page either does or doesn't use htmx.

## How to add a new `hx-*` attribute

Add a field to `HtmxAttrs` in `Htmx/Attrs.lean` (a closed vocabulary gets
its own enum, following `HxSwap`; most attributes stay `Option String`),
wire it into `HtmxAttrs.toPairs`, and add a test to
`test/HtmxTests/Attrs.lean`. Every per-element `Htmx.<Tag>Attrs` picks it
up automatically.

## How to add a new htmx-wrapped tag

Add a wrapper to `Htmx/Tags.lean` with exactly the same signature as the
matching `Html.*` tag. If that tag takes plain `Html.HtmlAttrs`, use
`HtmxAttrs` as `attrs`; if it takes its own `Html.<Tag>Attrs`, first add
`structure Htmx.<Tag>Attrs extends Html.<Tag>Attrs, HtmxAttrs` alongside
the others in `Htmx/Attrs.lean`, then use that. Add a smoke test to
`test/HtmxTests/Tags.lean`.
-/
