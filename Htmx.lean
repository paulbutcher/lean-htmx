/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

public import Html
public import Htmx.Attrs
public import Htmx.Tags

/-!
# `Htmx`: typed htmx attributes on top of `Html`

Built entirely on `Html`'s public API, using its `rawAttrs` escape hatch as
the delivery mechanism for this library's own typed values.

`HtmxAttrs` (`Htmx/Attrs.lean`) is one fixed structure holding the common
`hx-*` attributes, with a closed `HxSwap` enum for `hx-swap` so that
`hxSwap := some "banana"` is rejected at compile time. It extends
`Html.HtmlAttrs`, so it doubles as the attrs type for every tag that
otherwise takes plain `Html.HtmlAttrs`; elements with their own
`Html.<Tag>Attrs` get a matching `Htmx.<Tag>Attrs extends Html.<Tag>Attrs,
HtmxAttrs`. A new attribute is a field plus a case in `HtmxAttrs.toPairs`;
every per-element record picks it up from there.

Each tag in `Htmx/Tags.lean` keeps exactly the signature of the `Html.*`
tag it wraps, so the two are interchangeable at the call site.

The type safety here is over the attributes of a single element. An
`Htmx.div` produces a plain `Html.Node .flow`, indistinguishable from and
freely composable with what `Html.div` produces, so there is no
whole-document guarantee that a page either does or doesn't use htmx.
-/
