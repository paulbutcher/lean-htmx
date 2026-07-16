import Html.Escape

/-!
Tests for `Html.Escape`.
-/

namespace Tests

open Html

-- #guard tests: one per metacharacter, plus combinations.
#guard escape "<script>" = "&lt;script&gt;"
#guard escape "\"onclick=\"" = "&quot;onclick=&quot;"
#guard escape "a & b" = "a &amp; b"
#guard escape "" = ""
#guard escape "héllo wörld 日本語" = "héllo wörld 日本語"
#guard escape "&<>\"" = "&amp;&lt;&gt;&quot;"
#guard escape "&amp;" = "&amp;amp;"  -- already-escaped input isn't special-cased; re-escaping & first is correct
#guard renderAttr "class" "a\"b" = " class=\"a&quot;b\""
#guard renderAttr "href" "x" = " href=\"x\""

end Tests
