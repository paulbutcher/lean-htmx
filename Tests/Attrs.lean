import Html.Attrs

/-!
Tests for `Html.Attrs`.
-/

namespace Tests

open Html

-- #guard tests, one (or more) per attribute. Optional `String` fields are
-- set via the `Coe String (Option String)` instance above, not `some` --
-- see that instance's doc comment for why this is safe here.
#guard HtmlAttrs.render {} = ""
#guard HtmlAttrs.render { id := "x" } = " id=\"x\""
#guard HtmlAttrs.render { class_ := "a b" } = " class=\"a b\""
#guard HtmlAttrs.render { style := "color:red" } = " style=\"color:red\""
#guard HtmlAttrs.render { title := "t" } = " title=\"t\""
#guard HtmlAttrs.render { lang := "en" } = " lang=\"en\""
#guard HtmlAttrs.render { dir := "ltr" } = " dir=\"ltr\""
#guard HtmlAttrs.render { id := "x", class_ := "y" } = " id=\"x\" class=\"y\""
#guard HtmlAttrs.render { id := "x\"y" } = " id=\"x&quot;y\""  -- values still escaped

-- Regression test: a genuinely wrong-typed field still fails cleanly, not
-- with 1.2's opaque "Application type mismatch ... ?m.7" message -- see
-- the `Coe` instance's doc comment above for why.
/--
error: Type mismatch
  true
has type
  Bool
but is expected to have type
  Option String
-/
#guard_msgs in
example := HtmlAttrs.render { id := true }

#guard AAttrs.render { href := "https://example.com" } = " href=\"https://example.com\""
#guard AAttrs.render { href := "x", target := "_blank" } = " href=\"x\" target=\"_blank\""

#guard ImgAttrs.render { src := "a.png", alt := "desc" } = " src=\"a.png\" alt=\"desc\""

#guard ScriptAttrs.render { src := "/a.js" } = " src=\"/a.js\""
#guard ScriptAttrs.render { src := "/a.js", integrity := "sha384-x", crossorigin := "anonymous" }
  = " src=\"/a.js\" integrity=\"sha384-x\" crossorigin=\"anonymous\""

#guard LinkAttrs.render { rel := "stylesheet", href := "/style.css" }
  = " rel=\"stylesheet\" href=\"/style.css\""

#guard QAttrs.render {} = ""
#guard QAttrs.render { cite := "https://example.com" } = " cite=\"https://example.com\""

#guard TimeAttrs.render {} = ""
#guard TimeAttrs.render { datetime := "2026-07-14" } = " datetime=\"2026-07-14\""

#guard DataAttrs.render { value := "42" } = " value=\"42\""

#guard InsDelAttrs.render {} = ""
#guard InsDelAttrs.render { cite := "https://example.com", datetime := "2026-07-14" }
  = " cite=\"https://example.com\" datetime=\"2026-07-14\""

#guard ColAttrs.render {} = ""
#guard ColAttrs.render { span := "2" } = " span=\"2\""

#guard FieldsetAttrs.render {} = ""
#guard FieldsetAttrs.render { disabled := true, name := "x" } = " disabled name=\"x\""

#guard OptgroupAttrs.render { label := "Fruit" } = " label=\"Fruit\""
#guard OptgroupAttrs.render { label := "Fruit", disabled := true } = " label=\"Fruit\" disabled"

#guard OutputAttrs.render {} = ""
#guard OutputAttrs.render { for_ := "a b", name := "result" } = " for=\"a b\" name=\"result\""

#guard ProgressAttrs.render {} = ""
#guard ProgressAttrs.render { value := "50", max := "100" } = " value=\"50\" max=\"100\""

#guard MeterAttrs.render {} = ""
#guard MeterAttrs.render { value := "6", min := "0", max := "10" }
  = " value=\"6\" min=\"0\" max=\"10\""

#guard OpenAttrs.render {} = ""
#guard OpenAttrs.render { open_ := true } = " open"

#guard BaseAttrs.render {} = ""
#guard BaseAttrs.render { href := "/", target := "_blank" } = " href=\"/\" target=\"_blank\""

#guard CanvasAttrs.render {} = ""
#guard CanvasAttrs.render { width := "300", height := "150" } = " width=\"300\" height=\"150\""

#guard SlotAttrs.render {} = ""
#guard SlotAttrs.render { name := "header" } = " name=\"header\""

#guard SourceAttrs.render {} = ""
#guard SourceAttrs.render { src := "a.mp4", type := "video/mp4" }
  = " src=\"a.mp4\" type=\"video/mp4\""

#guard TrackAttrs.render { src := "a.vtt" } = " src=\"a.vtt\""
#guard TrackAttrs.render { src := "a.vtt", kind := "subtitles", srclang := "en", default := true }
  = " src=\"a.vtt\" kind=\"subtitles\" srclang=\"en\" default"

#guard IframeAttrs.render { src := "/embed" } = " src=\"/embed\""
#guard IframeAttrs.render { src := "/embed", title := "t", width := "300", height := "150" }
  = " src=\"/embed\" title=\"t\" width=\"300\" height=\"150\""

#guard EmbedAttrs.render {} = ""
#guard EmbedAttrs.render { src := "a.swf", type := "application/x-shockwave-flash" }
  = " src=\"a.swf\" type=\"application/x-shockwave-flash\""

#guard ObjectAttrs.render {} = ""
#guard ObjectAttrs.render { data := "a.pdf", type := "application/pdf" }
  = " data=\"a.pdf\" type=\"application/pdf\""

#guard VideoAttrs.render {} = ""
#guard VideoAttrs.render { src := "a.mp4", controls := true } = " src=\"a.mp4\" controls"

#guard AudioAttrs.render {} = ""
#guard AudioAttrs.render { src := "a.mp3", controls := true } = " src=\"a.mp3\" controls"

#guard MapAttrs.render { name := "sitemap" } = " name=\"sitemap\""

#guard AreaAttrs.render {} = ""
#guard AreaAttrs.render { href := "#a", alt := "Area A", shape := "rect", coords := "0,0,10,10" }
  = " href=\"#a\" alt=\"Area A\" shape=\"rect\" coords=\"0,0,10,10\""

#guard InputAttrs.render {} = " type=\"text\""
#guard InputAttrs.render { disabled := true } = " type=\"text\" disabled"
#guard InputAttrs.render { disabled := false } = " type=\"text\""  -- explicit: never `disabled="false"`
#guard InputAttrs.render { checked := true, required := true } = " type=\"text\" checked required"
#guard InputAttrs.render { name := "q", value := "v" } = " type=\"text\" name=\"q\" value=\"v\""

#guard renderBoolAttr "disabled" true = " disabled"
#guard renderBoolAttr "disabled" false = ""

-- rawAttrs: values are escaped, but names are intentionally NOT validated
-- (documenting the gap, not fixing it -- see docs/html-library-plan.md 1.3).
#guard renderRawAttrs [("data-x", "a\"b")] = " data-x=\"a&quot;b\""
#guard renderRawAttrs [("hx-get", "/x"), ("hx-target", "#y")] = " hx-get=\"/x\" hx-target=\"#y\""
#guard renderRawAttrs [("evil onmouseover=\"alert(1)", "x")]
  = " evil onmouseover=\"alert(1)=\"x\""  -- a space in the name breaks out of the tag; unchecked by design

end Tests
