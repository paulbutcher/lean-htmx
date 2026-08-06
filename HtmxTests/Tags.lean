import Htmx.Tags

namespace HtmxTests

open Htmx

#guard Html.Node.render (div [] { hxGet := "/x" }) = "<div hx-get=\"/x\"></div>"
#guard Html.Node.render (button [Html.Node.text "Go"] { hxPost := "/go", hxTarget := "#r" })
  = "<button type=\"submit\" hx-post=\"/go\" hx-target=\"#r\">Go</button>"
#guard Html.Node.render (a { href := "#", hxGet := "/x" } []) = "<a href=\"#\" hx-get=\"/x\"></a>"
#guard Html.Node.render (input { hxGet := "/search", hxTrigger := "keyup" })
  = "<input type=\"text\" hx-get=\"/search\" hx-trigger=\"keyup\">"
#guard Html.Node.render (form [] { hxPost := "/submit" }) = "<form hx-post=\"/submit\"></form>"
#guard Html.Node.render (img { src := "a.png", alt := "d", hxGet := "/refresh" })
  = "<img src=\"a.png\" alt=\"d\" hx-get=\"/refresh\">"
#guard Html.Node.render (textarea "hi" { hxTrigger := "change" })
  = "<textarea hx-trigger=\"change\">hi</textarea>"
#guard Html.Node.render (option "hi" { hxGet := "/x" }) = "<option hx-get=\"/x\">hi</option>"
#guard Html.Node.render (br) = "<br>"
#guard Html.Node.render (hr { hxGet := "/x" }) = "<hr hx-get=\"/x\">"
#guard Html.Node.render (tr [td [] { hxGet := "/x" }]) = "<tr><td hx-get=\"/x\"></td></tr>"

-- Per-tag attrs records merge the element's own `Html.<Tag>Attrs` fields
-- alongside the `hx-*` ones, one #guard per updated wrapper.
#guard Html.Node.render (form [] { action := "/s", method := "post" })
  = "<form action=\"/s\" method=\"post\"></form>"
#guard Html.Node.render (label [] { for_ := "x" }) = "<label for=\"x\"></label>"
#guard Html.Node.render (textarea "hi" { disabled := true })
  = "<textarea disabled>hi</textarea>"
#guard Html.Node.render (option "hi" { selected := true }) = "<option selected>hi</option>"
#guard Html.Node.render (select [] { multiple := true }) = "<select multiple></select>"
#guard Html.Node.render (button [] { disabled := true })
  = "<button type=\"submit\" disabled></button>"
#guard Html.Node.render (ol [] { reversed := true }) = "<ol reversed></ol>"
#guard Html.Node.render (li [] { value := "3" }) = "<li value=\"3\"></li>"
#guard Html.Node.render (blockquote [] { cite := "http://x" })
  = "<blockquote cite=\"http://x\"></blockquote>"
#guard Html.Node.render (th [] { colspan := "2" }) = "<th colspan=\"2\"></th>"
#guard Html.Node.render (td [] { colspan := "2" }) = "<td colspan=\"2\"></td>"

 -- Composition: an Htmx tag nests inside a plain Html tag and vice versa --
-- `hx-*` fields never leak into `Node`'s type (1.4), so both directions typecheck.
#guard Html.Node.render (Html.div [div [] { hxGet := "/x" }])
  = "<div><div hx-get=\"/x\"></div></div>"
#guard Html.Node.render (div [Html.p [Html.Node.text "hi"]] { hxGet := "/x" })
  = "<div hx-get=\"/x\"><p>hi</p></div>"

-- rawAttrs still composes alongside the typed attrs, same as every Html tag.
#guard Html.Node.render (div [] { hxGet := "/x", id := "y" } [("data-z", "1")])
  = "<div id=\"y\" hx-get=\"/x\" data-z=\"1\"></div>"

end HtmxTests
