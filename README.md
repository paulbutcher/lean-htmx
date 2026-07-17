# Htmx

Typed [htmx](https://htmx.org/) attributes for the
[`Html`](https://github.com/paulbutcher/lean-html) Lean library. Every
`Html` tag has a matching `Htmx` wrapper that takes an extra `hx`
argument for `hx-*` attributes, checked at compile time.

## Installation

Add to your `lakefile.toml`:

```toml
[[require]]
name = "htmx"
git = "https://github.com/paulbutcher/lean-htmx"
rev = "main"
```

## Usage

```lean
import Htmx.Tags

open Htmx

#eval Html.Node.render
  (div [] { hxGet := "/items", hxTarget := "#list", hxSwap := .outerHTML })
-- <div hx-get="/items" hx-target="#list" hx-swap="outerHTML"></div>
```

Each `Htmx` tag (`Htmx.div`, `Htmx.button`, `Htmx.form`, ...) has the same
signature as the corresponding `Html` tag, plus an `hx : HtmxAttrs := {}`
parameter. `Htmx` and `Html` nodes compose freely in either direction.
Render with `Html.Node.render` (or `Html.Node.renderPretty`) as usual.

`HtmxAttrs` covers the common `hx-*` attributes (`hxGet`, `hxPost`,
`hxPut`, `hxPatch`, `hxDelete`, `hxTrigger`, `hxTarget`, `hxSwap`,
`hxSwapOob`, `hxSelect`, `hxSelectOob`, `hxPushUrl`, `hxConfirm`,
`hxIndicator`, `hxVals`, `hxBoost`, `hxExt`, `hxParams`). `hx-swap` is a
closed enum (`HxSwap`), so invalid values are rejected at compile time.
Anything not covered can still be passed through a tag's `rawAttrs`
parameter, as with plain `Html` tags.

## License

This library is released under the Apache 2.0 license. See the LICENSE
file for the complete license text.
