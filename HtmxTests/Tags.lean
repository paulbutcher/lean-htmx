import Htmx.Tags

/-!
Tests for `Htmx.Tags`.
-/

namespace HtmxTests

open Htmx

-- #guard smoke test per tag: hx attributes render as ordinary rawAttrs,
-- and the result is a plain Html.Node -- fully interoperable with Html's
-- own tag functions (e.g. the `p`/`strong` nesting below).
#guard Html.Node.render (div [] { hxGet := "/x" }) = "<div hx-get=\"/x\"></div>"
#guard Html.Node.render (button [Html.Node.text "Go"] { hxPost := "/go", hxTarget := "#r" })
  = "<button hx-post=\"/go\" hx-target=\"#r\">Go</button>"
#guard Html.Node.render (a { href := "#" } [] { hxGet := "/x" }) = "<a href=\"#\" hx-get=\"/x\"></a>"
#guard Html.Node.render (input { type := "text" } { hxGet := "/search", hxTrigger := "keyup" })
  = "<input type=\"text\" hx-get=\"/search\" hx-trigger=\"keyup\">"
#guard Html.Node.render (form [] { hxPost := "/submit" }) = "<form hx-post=\"/submit\"></form>"
#guard Html.Node.render (img { src := "a.png", alt := "d" } { hxGet := "/refresh" })
  = "<img src=\"a.png\" alt=\"d\" hx-get=\"/refresh\">"
#guard Html.Node.render (textarea "hi" { hxTrigger := "change" })
  = "<textarea hx-trigger=\"change\">hi</textarea>"
#guard Html.Node.render (option "hi" { hxGet := "/x" }) = "<option hx-get=\"/x\">hi</option>"
#guard Html.Node.render (br) = "<br>"
#guard Html.Node.render (hr { hxGet := "/x" }) = "<hr hx-get=\"/x\">"
#guard Html.Node.render (tr [td [] { hxGet := "/x" }]) = "<tr><td hx-get=\"/x\"></td></tr>"

-- Composition: an Htmx tag nests inside a plain Html tag and vice versa --
-- `hx` never leaks into `Node`'s type (1.4), so both directions typecheck.
#guard Html.Node.render (Html.div [div [] { hxGet := "/x" }])
  = "<div><div hx-get=\"/x\"></div></div>"
#guard Html.Node.render (div [Html.p [Html.Node.text "hi"]] { hxGet := "/x" })
  = "<div hx-get=\"/x\"><p>hi</p></div>"

-- attrs/rawAttrs still compose alongside hx, same as every Html tag --
-- attrs (HtmlAttrs) render before hx/rawAttrs, since hx is folded into the
-- `rawAttrs` argument forwarded to `Html.div`, positionally after `attrs`.
-- `{ id := "y" }` here is `Html.HtmlAttrs`, so it relies on `Html`'s scoped
-- `Coe` instance, not `Htmx`'s -- both are in scope via `import Html`
-- resolving qualified access, confirmed by this guard actually compiling.
#guard Html.Node.render (div [] { hxGet := "/x" } { id := "y" } [("data-z", "1")])
  = "<div id=\"y\" hx-get=\"/x\" data-z=\"1\"></div>"

end HtmxTests
