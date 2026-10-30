/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

import Htmx.Tags
meta import Htmx.Tags

namespace HtmxTests

open Htmx

-- One smoke test per wrapper: the `hx-*` attributes reach the element the wrapper
-- claims to build.
#guard Html.Node.render (div [] { hxGet := "/x" }) = "<div hx-get=\"/x\"></div>"
#guard Html.Node.render (section_ [] { hxGet := "/x" }) = "<section hx-get=\"/x\"></section>"
#guard Html.Node.render (article [] { hxGet := "/x" }) = "<article hx-get=\"/x\"></article>"
#guard Html.Node.render (header [] { hxGet := "/x" }) = "<header hx-get=\"/x\"></header>"
#guard Html.Node.render (footer [] { hxGet := "/x" }) = "<footer hx-get=\"/x\"></footer>"
#guard Html.Node.render (nav [] { hxGet := "/x" }) = "<nav hx-get=\"/x\"></nav>"
#guard Html.Node.render (p [] { hxGet := "/x" }) = "<p hx-get=\"/x\"></p>"
#guard Html.Node.render (h1 [] { hxGet := "/x" }) = "<h1 hx-get=\"/x\"></h1>"
#guard Html.Node.render (h2 [] { hxGet := "/x" }) = "<h2 hx-get=\"/x\"></h2>"
#guard Html.Node.render (h3 [] { hxGet := "/x" }) = "<h3 hx-get=\"/x\"></h3>"
#guard Html.Node.render (h4 [] { hxGet := "/x" }) = "<h4 hx-get=\"/x\"></h4>"
#guard Html.Node.render (h5 [] { hxGet := "/x" }) = "<h5 hx-get=\"/x\"></h5>"
#guard Html.Node.render (h6 [] { hxGet := "/x" }) = "<h6 hx-get=\"/x\"></h6>"
#guard Html.Node.render (ul [] { hxGet := "/x" }) = "<ul hx-get=\"/x\"></ul>"
#guard Html.Node.render (ol [] { hxGet := "/x" }) = "<ol hx-get=\"/x\"></ol>"
#guard Html.Node.render (li [] { hxGet := "/x" }) = "<li hx-get=\"/x\"></li>"
#guard Html.Node.render (blockquote [] { hxGet := "/x" })
  = "<blockquote hx-get=\"/x\"></blockquote>"
#guard Html.Node.render (pre [] { hxGet := "/x" }) = "<pre hx-get=\"/x\"></pre>"
#guard Html.Node.render (code [] { hxGet := "/x" }) = "<code hx-get=\"/x\"></code>"
#guard Html.Node.render (a { href := "#", hxGet := "/x" } []) = "<a href=\"#\" hx-get=\"/x\"></a>"
#guard Html.Node.render (strong [] { hxGet := "/x" }) = "<strong hx-get=\"/x\"></strong>"
#guard Html.Node.render (em [] { hxGet := "/x" }) = "<em hx-get=\"/x\"></em>"
#guard Html.Node.render (small [] { hxGet := "/x" }) = "<small hx-get=\"/x\"></small>"
#guard Html.Node.render (br) = "<br>"
#guard Html.Node.render (form [] { hxPost := "/submit" }) = "<form hx-post=\"/submit\"></form>"
#guard Html.Node.render (input { hxGet := "/search", hxTrigger := "keyup" })
  = "<input type=\"text\" hx-get=\"/search\" hx-trigger=\"keyup\">"
#guard Html.Node.render (label [] { hxGet := "/x" }) = "<label hx-get=\"/x\"></label>"
#guard Html.Node.render (textarea "hi" { hxTrigger := "change" })
  = "<textarea hx-trigger=\"change\">hi</textarea>"
#guard Html.Node.render (option "hi" { hxGet := "/x" }) = "<option hx-get=\"/x\">hi</option>"
#guard Html.Node.render (select [] { hxGet := "/x" }) = "<select hx-get=\"/x\"></select>"
#guard Html.Node.render (button [Html.Node.text "Go"] { hxPost := "/go", hxTarget := "#r" })
  = "<button type=\"submit\" hx-post=\"/go\" hx-target=\"#r\">Go</button>"
#guard Html.Node.render (img { src := "a.png", alt := "d", hxGet := "/refresh" })
  = "<img src=\"a.png\" alt=\"d\" hx-get=\"/refresh\">"
#guard Html.Node.render (hr { hxGet := "/x" }) = "<hr hx-get=\"/x\">"
#guard Html.Node.render (table (attrs := { hxGet := "/x" })) = "<table hx-get=\"/x\"></table>"
#guard Html.Node.render (thead [] { hxGet := "/x" }) = "<thead hx-get=\"/x\"></thead>"
#guard Html.Node.render (tbody [] { hxGet := "/x" }) = "<tbody hx-get=\"/x\"></tbody>"
#guard Html.Node.render (tfoot [] { hxGet := "/x" }) = "<tfoot hx-get=\"/x\"></tfoot>"
#guard Html.Node.render (tr [td [] { hxGet := "/x" }]) = "<tr><td hx-get=\"/x\"></td></tr>"
#guard Html.Node.render (th [] { hxGet := "/x" }) = "<th hx-get=\"/x\"></th>"

-- Per-tag attrs records carry the element's own `Html.<Tag>Attrs` fields alongside
-- the `hx-*` ones.
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

-- Composition: an Htmx tag nests inside a plain Html tag and vice versa, since
-- `hx-*` fields never leak into `Node`'s type.
#guard Html.Node.render (Html.div [div [] { hxGet := "/x" }])
  = "<div><div hx-get=\"/x\"></div></div>"
#guard Html.Node.render (div [Html.p [Html.Node.text "hi"]] { hxGet := "/x" })
  = "<div hx-get=\"/x\"><p>hi</p></div>"

-- rawAttrs still composes alongside the typed attrs, same as every Html tag.
#guard Html.Node.render (div [] { hxGet := "/x", id := "y" } [("data-z", "1")])
  = "<div id=\"y\" hx-get=\"/x\" data-z=\"1\"></div>"

end HtmxTests
