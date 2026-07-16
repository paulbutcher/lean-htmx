import Html.Node
import Html.Tags

/-!
Tests for `Html.Tags`.
-/

namespace Tests

open Html

-- #guard smoke test per tag: minimal render output, no attrs.
#guard Node.render (div []) = "<div></div>"
#guard Node.render (section_ []) = "<section></section>"
#guard Node.render (article []) = "<article></article>"
#guard Node.render (header []) = "<header></header>"
#guard Node.render (footer []) = "<footer></footer>"
#guard Node.render (nav []) = "<nav></nav>"
#guard Node.render (aside []) = "<aside></aside>"
#guard Node.render (hgroup []) = "<hgroup></hgroup>"
#guard Node.render (address []) = "<address></address>"
#guard Node.render (main []) = "<main></main>"
#guard Node.render (search []) = "<search></search>"
#guard Node.render (p []) = "<p></p>"
#guard Node.render (h1 []) = "<h1></h1>"
#guard Node.render (h2 []) = "<h2></h2>"
#guard Node.render (h3 []) = "<h3></h3>"
#guard Node.render (h4 []) = "<h4></h4>"
#guard Node.render (h5 []) = "<h5></h5>"
#guard Node.render (h6 []) = "<h6></h6>"
#guard Node.render (ul []) = "<ul></ul>"
#guard Node.render (ol []) = "<ol></ol>"
#guard Node.render (li []) = "<li></li>"
#guard Node.render (menu []) = "<menu></menu>"
#guard Node.render (dl []) = "<dl></dl>"
#guard Node.render (dt []) = "<dt></dt>"
#guard Node.render (dd []) = "<dd></dd>"
#guard Node.render (blockquote []) = "<blockquote></blockquote>"
#guard Node.render (figure []) = "<figure></figure>"
#guard Node.render (figcaption []) = "<figcaption></figcaption>"
#guard Node.render (pre []) = "<pre></pre>"
#guard Node.render (code []) = "<code></code>"
#guard Node.render (base) = "<base>"
#guard Node.render (base { href := "/", target := "_blank" }) = "<base href=\"/\" target=\"_blank\">"
#guard Node.render (noscript []) = "<noscript></noscript>"
#guard Node.render (template []) = "<template></template>"
#guard Node.render (canvas []) = "<canvas></canvas>"
#guard Node.render (canvas [] { width := "300", height := "150" })
  = "<canvas width=\"300\" height=\"150\"></canvas>"
#guard Node.render (slot []) = "<slot></slot>"
#guard Node.render (slot [] { name := "header" }) = "<slot name=\"header\"></slot>"
#guard Node.render (a { href := "x" } []) = "<a href=\"x\"></a>"
#guard Node.render (strong []) = "<strong></strong>"
#guard Node.render (em []) = "<em></em>"
#guard Node.render (small []) = "<small></small>"
#guard Node.render (span []) = "<span></span>"
#guard Node.render (i []) = "<i></i>"
#guard Node.render (b []) = "<b></b>"
#guard Node.render (u []) = "<u></u>"
#guard Node.render (s []) = "<s></s>"
#guard Node.render (mark []) = "<mark></mark>"
#guard Node.render (cite []) = "<cite></cite>"
#guard Node.render (dfn []) = "<dfn></dfn>"
#guard Node.render (abbr []) = "<abbr></abbr>"
#guard Node.render (var []) = "<var></var>"
#guard Node.render (samp []) = "<samp></samp>"
#guard Node.render (kbd []) = "<kbd></kbd>"
#guard Node.render (sub []) = "<sub></sub>"
#guard Node.render (sup []) = "<sup></sup>"
#guard Node.render (bdi []) = "<bdi></bdi>"
#guard Node.render (bdo []) = "<bdo></bdo>"
#guard Node.render (ruby []) = "<ruby></ruby>"
#guard Node.render (rt []) = "<rt></rt>"
#guard Node.render (rp []) = "<rp></rp>"
#guard Node.render (wbr) = "<wbr>"
#guard Node.render (q []) = "<q></q>"
#guard Node.render (q [] { cite := "https://example.com" })
  = "<q cite=\"https://example.com\"></q>"
#guard Node.render (time []) = "<time></time>"
#guard Node.render (time [] { datetime := "2026-07-14" })
  = "<time datetime=\"2026-07-14\"></time>"
#guard Node.render (data { value := "42" } []) = "<data value=\"42\"></data>"
#guard Node.render (ins (cat := .flow) []) = "<ins></ins>"
#guard Node.render (del (cat := .phrasing) []) = "<del></del>"
#guard Node.render (br) = "<br>"
#guard Node.render (form []) = "<form></form>"
#guard Node.render (fieldset []) = "<fieldset></fieldset>"
#guard Node.render (fieldset [] { disabled := true }) = "<fieldset disabled></fieldset>"
#guard Node.render (legend []) = "<legend></legend>"
#guard Node.render (input) = "<input type=\"text\">"
#guard Node.render (label []) = "<label></label>"
#guard Node.render (textarea "hi") = "<textarea>hi</textarea>"
#guard Node.render (option "hi") = "<option>hi</option>"
#guard Node.render (select []) = "<select></select>"
#guard Node.render (datalist []) = "<datalist></datalist>"
#guard Node.render (optgroup { label := "Fruit" } []) = "<optgroup label=\"Fruit\"></optgroup>"
#guard Node.render (button []) = "<button></button>"
#guard Node.render (output []) = "<output></output>"
#guard Node.render (output [] { for_ := "a b", name := "result" })
  = "<output for=\"a b\" name=\"result\"></output>"
#guard Node.render (progress []) = "<progress></progress>"
#guard Node.render (progress [] { value := "50", max := "100" })
  = "<progress value=\"50\" max=\"100\"></progress>"
#guard Node.render (meter []) = "<meter></meter>"
#guard Node.render (meter [] { value := "6", min := "0", max := "10" })
  = "<meter value=\"6\" min=\"0\" max=\"10\"></meter>"
#guard Node.render (details []) = "<details></details>"
#guard Node.render (details [] { open_ := true }) = "<details open></details>"
#guard Node.render (summary []) = "<summary></summary>"
#guard Node.render (dialog []) = "<dialog></dialog>"
#guard Node.render (dialog [] { open_ := true }) = "<dialog open></dialog>"
#guard Node.render (img { src := "a.png", alt := "d" }) = "<img src=\"a.png\" alt=\"d\">"
#guard Node.render (hr) = "<hr>"
#guard Node.render (picture []) = "<picture></picture>"
#guard Node.render (source) = "<source>"
#guard Node.render (source { src := "a.mp4", type := "video/mp4" })
  = "<source src=\"a.mp4\" type=\"video/mp4\">"
#guard Node.render (track { src := "a.vtt" }) = "<track src=\"a.vtt\">"
#guard Node.render (iframe { src := "/embed" }) = "<iframe src=\"/embed\"></iframe>"
#guard Node.render (embed) = "<embed>"
#guard Node.render (embed { src := "a.swf" }) = "<embed src=\"a.swf\">"
#guard Node.render (object) = "<object></object>"
#guard Node.render (object { data := "a.pdf" }) = "<object data=\"a.pdf\"></object>"
#guard Node.render (video) = "<video></video>"
#guard Node.render (video (videoAttrs := { src := "a.mp4", controls := true }))
  = "<video src=\"a.mp4\" controls></video>"
#guard Node.render (audio) = "<audio></audio>"
#guard Node.render (audio (audioAttrs := { src := "a.mp3", controls := true }))
  = "<audio src=\"a.mp3\" controls></audio>"
#guard Node.render (map { name := "sitemap" }) = "<map name=\"sitemap\"></map>"
#guard Node.render (area) = "<area>"
#guard Node.render (area { href := "#a", alt := "Area A" }) = "<area href=\"#a\" alt=\"Area A\">"
#guard Node.render (table []) = "<table></table>"
#guard Node.render (caption []) = "<caption></caption>"
#guard Node.render (colgroup []) = "<colgroup></colgroup>"
#guard Node.render (col) = "<col>"
#guard Node.render (col { span := "2" }) = "<col span=\"2\">"
#guard Node.render (tfoot []) = "<tfoot></tfoot>"
#guard Node.render (thead []) = "<thead></thead>"
#guard Node.render (tbody []) = "<tbody></tbody>"
#guard Node.render (tr []) = "<tr></tr>"
#guard Node.render (th []) = "<th></th>"
#guard Node.render (td []) = "<td></td>"

-- Composition smoke tests: nesting, phrasing coercion into flow, text
-- leaves, attributes, rawAttrs, and unsafeRaw all working together.
#guard Node.render (div [p ["Hello, "], strong ["world"]])
  = "<div><p>Hello, </p><strong>world</strong></div>"
#guard Node.render (p ["a < b & c"]) = "<p>a &lt; b &amp; c</p>"
#guard Node.render (div [] { id := "x", class_ := "y" })
  = "<div id=\"x\" class=\"y\"></div>"
#guard Node.render (div [] {} [("data-x", "1")]) = "<div data-x=\"1\"></div>"
#guard Node.render (div [(Node.unsafeRaw "<b>raw</b>" : Node .flow)])
  = "<div><b>raw</b></div>"
#guard Node.render (ul [li [Node.text "one"], li [Node.text "two"]])
  = "<ul><li>one</li><li>two</li></ul>"

-- Negative-compile regression: `p` only accepts phrasing children, so a
-- `<div>` (flow) directly inside a `<p>` must fail to typecheck -- this is
-- content-model correctness as a corollary of type soundness (1.1),
-- checked by `#guard_msgs` rather than left as a "should fail" comment
-- (per Phase 4/1.7: confirmed this works instead of reaching for a
-- separate negative-compile CI mechanism).
/--
error: Application type mismatch: The argument
  div []
has type
  Node Category.flow
but is expected to have type
  Node Category.phrasing
in the application
  List.cons (div [])
-/
#guard_msgs in
example : Node .flow := p [div []]

-- Pretty-printing (Phase 6), end-to-end through real tags: block-vs-inline
-- layout composes correctly, and whitespace-significant content
-- (`pre`/`textarea`) is never touched regardless of surrounding layout.
#guard Node.renderPretty (div [p ["Hello, "], strong ["world"]])
  = "<div>\n  <p>Hello, </p>\n  <strong>world</strong>\n</div>"
#guard Node.renderPretty (ul [li [Node.text "one"], li [Node.text "two"]])
  = "<ul>\n  <li>one</li>\n  <li>two</li>\n</ul>"
#guard Node.renderPretty (div [(pre [Node.text "line1\n  line2"] : Node .flow)])
  = "<div>\n  <pre>line1\n  line2</pre>\n</div>"
#guard Node.renderPretty (div [(textarea "line1\nline2  spaced" : Node .flow)])
  = "<div>\n  <textarea>line1\nline2  spaced</textarea>\n</div>"

-- `Coe String (Option String)` (Html/Attrs.lean) applies at a real tag call
-- site too, not just a bare struct literal.
#guard Node.render (div [] (attrs := { id := "x", class_ := "y" }))
  = "<div id=\"x\" class=\"y\"></div>"
#guard Node.render (a (linkAttrs := { href := "/x", target := "_blank" }) [Node.text "go"])
  = "<a href=\"/x\" target=\"_blank\">go</a>"

-- `ins`/`del`'s transparent content model (see their doc comment): the
-- *same* definitions resolve to a phrasing element directly inside a `<p>`
-- and to a flow element directly inside a `<div>`, with no manual type
-- ascription at either call site -- `cat` is inferred from context both
-- ways.
#guard Node.render (p [Node.text "Some ", del ["old"], Node.text " ", ins ["new"], Node.text " text"])
  = "<p>Some <del>old</del> <ins>new</ins> text</p>"
#guard Node.render (div [ins [p ["whole paragraph added"]]])
  = "<div><ins><p>whole paragraph added</p></ins></div>"

end Tests
