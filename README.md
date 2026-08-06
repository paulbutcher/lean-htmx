# Htmx

Typed [htmx](https://htmx.org/) attributes for the
[`Html`](https://github.com/paulbutcher/lean-html) Lean library. Every
`Html` tag has a matching `Htmx` wrapper whose single `attrs` argument also
carries `hx-*` attributes, checked at compile time.

See: [Formally verified CRUD](https://paulbutcher.com/lean2.html).

## Installation

Add to your `lakefile.toml`:

```toml
[[require]]
name = "htmx"
git = "https://github.com/paulbutcher/lean-htmx"
```

## Usage

```lean
import Htmx.Tags

open Htmx

#eval Html.Node.render
  (div [] { hxGet := "/items", hxTarget := "#list", hxSwap := .outerHTML })
-- <div hx-get="/items" hx-target="#list" hx-swap="outerHTML"></div>
```

Each `Htmx` tag (`Htmx.div`, `Htmx.button`, `Htmx.form`, ...) has
the same signature as the corresponding `Html` tag -- children, a single
`attrs` record, and `rawAttrs`. That `attrs` type is `HtmxAttrs` (for tags
that would otherwise take plain `Html.HtmlAttrs`) or a per-element
`Htmx.<Tag>Attrs` (for tags with their own `Html.<Tag>Attrs`, e.g.
`Htmx.FormAttrs`, `Htmx.ImgAttrs`), each of which merges the element's own
HTML fields with the `hx-*` ones, so both are set in the same literal:
`div [] { id := "x", hxGet := "/items", hxTarget := "#list", hxSwap := .outerHTML }`.
`Htmx` and `Html` nodes compose freely in either direction. Render with
`Html.Node.render` (or `Html.Node.renderPretty`) as usual.

`HtmxAttrs` covers the common `hx-*` attributes (`hxGet`, `hxPost`,
`hxPut`, `hxPatch`, `hxDelete`, `hxTrigger`, `hxTarget`, `hxSwap`,
`hxSwapOob`, `hxSelect`, `hxSelectOob`, `hxPushUrl`, `hxConfirm`,
`hxIndicator`, `hxVals`, `hxBoost`, `hxExt`, `hxParams`, `hxOn`,
`hxOnHtmx`), alongside the global `HtmlAttrs` fields it extends (`id`,
`class_`, `style`, `title`, `lang`, `dir`). `hx-swap` is a closed enum
(`HxSwap`), so invalid values are rejected at compile time. Anything not
covered can still be passed through a tag's `rawAttrs` parameter, as with
plain `Html` tags.

`hxOn` and `hxOnHtmx` cover `hx-on:<event>` (plain DOM events) and
`hx-on::<event>` (htmx-dispatched events), each as a `List (String ×
String)` of `(event, jsCode)` pairs:

```lean
#eval Html.Node.render
  (button [] { hxOnHtmx := [("before-request", "console.log('sending')")] })
-- <button hx-on::before-request="console.log('sending')"></button>
```

## License

This library is released under the Apache 2.0 license. See the LICENSE
file for the complete license text.
