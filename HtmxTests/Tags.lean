import Htmx.Tags

namespace HtmxTests

open Htmx

#guard Html.Node.render (div [] { hxGet := "/x" }) = "<div hx-get=\"/x\"></div>"
#guard Html.Node.render (button [Html.Node.text "Go"] (hx := { hxPost := "/go", hxTarget := "#r" }))
  = "<button type=\"submit\" hx-post=\"/go\" hx-target=\"#r\">Go</button>"
#guard Html.Node.render (a { href := "#" } [] { hxGet := "/x" }) = "<a href=\"#\" hx-get=\"/x\"></a>"
#guard Html.Node.render (input { type := "text" } { hxGet := "/search", hxTrigger := "keyup" })
  = "<input type=\"text\" hx-get=\"/search\" hx-trigger=\"keyup\">"
#guard Html.Node.render (form [] (hx := { hxPost := "/submit" })) = "<form hx-post=\"/submit\"></form>"
#guard Html.Node.render (img { src := "a.png", alt := "d" } { hxGet := "/refresh" })
  = "<img src=\"a.png\" alt=\"d\" hx-get=\"/refresh\">"
#guard Html.Node.render (textarea "hi" (hx := { hxTrigger := "change" }))
  = "<textarea hx-trigger=\"change\">hi</textarea>"
#guard Html.Node.render (option "hi" (hx := { hxGet := "/x" })) = "<option hx-get=\"/x\">hi</option>"
#guard Html.Node.render (br) = "<br>"
#guard Html.Node.render (hr { hxGet := "/x" }) = "<hr hx-get=\"/x\">"
#guard Html.Node.render (tr [td [] (hx := { hxGet := "/x" })]) = "<tr><td hx-get=\"/x\"></td></tr>"

-- New per-tag attrs records forwarded from `Html.<tag>`, one #guard per updated wrapper.
#guard Html.Node.render (form [] (formAttrs := { action := "/s", method := "post" }))
  = "<form action=\"/s\" method=\"post\"></form>"
#guard Html.Node.render (label [] (labelAttrs := { for_ := "x" })) = "<label for=\"x\"></label>"
#guard Html.Node.render (textarea "hi" (textareaAttrs := { disabled := true }))
  = "<textarea disabled>hi</textarea>"
#guard Html.Node.render (option "hi" (optionAttrs := { selected := true })) = "<option selected>hi</option>"
#guard Html.Node.render (select [] (selectAttrs := { multiple := true })) = "<select multiple></select>"
#guard Html.Node.render (button [] (buttonAttrs := { disabled := true }))
  = "<button type=\"submit\" disabled></button>"
#guard Html.Node.render (ol [] (olAttrs := { reversed := true })) = "<ol reversed></ol>"
#guard Html.Node.render (li [] (liAttrs := { value := "3" })) = "<li value=\"3\"></li>"
#guard Html.Node.render (blockquote [] (blockquoteAttrs := { cite := "http://x" }))
  = "<blockquote cite=\"http://x\"></blockquote>"
#guard Html.Node.render (th [] (thAttrs := { colspan := "2" })) = "<th colspan=\"2\"></th>"
#guard Html.Node.render (td [] (tdAttrs := { colspan := "2" })) = "<td colspan=\"2\"></td>"

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
