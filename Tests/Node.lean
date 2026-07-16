import Html.Node

/-!
Tests for `Html.Node`.
-/

namespace Tests

open Html

-- Node-shape regression tests (Phase 1): minimal render output for a
-- normal element and a void element. No attributes yet (Phase 3) and no
-- escaping yet (Phase 2), so nothing attribute- or text-bearing here.
#guard Node.render (Node.element .flow "div" []) = "<div></div>"
#guard Node.render (Node.element .flow "div" [Node.element .flow "p" []]) = "<div><p></p></div>"
#guard Node.render (Node.voidElement .flow "br") = "<br>"
#guard Node.render
    (Node.element .flow "ul" [Node.element .flow "li" [], Node.element .flow "li" []])
  = "<ul><li></li><li></li></ul>"
#guard Node.render ((Node.element .phrasing "span" [] : Node .phrasing) : Node .flow) = "<span></span>"

-- String literals coerce directly to a `text` leaf (no `Node.text` needed).
#guard Node.render (Node.element .flow "p" [("hi" : Node .flow)]) = "<p>hi</p>"

-- Pretty-printing (Phase 6): empty and void elements stay one line.
#guard Node.renderPretty (Node.element .flow "div" []) = "<div></div>"
#guard Node.renderPretty (Node.voidElement .flow "br") = "<br>"

-- A lone leaf child (text or `unsafeRaw`) isn't worth exploding onto its
-- own line, whether the element's declared content category is flow or
-- phrasing.
#guard Node.renderPretty (Node.element .flow "li" [Node.text "one"]) = "<li>one</li>"
#guard Node.renderPretty (Node.element .flow "div" [(Node.unsafeRaw "<b>x</b>" : Node .flow)])
  = "<div><b>x</b></div>"

-- A lone *structured* (non-leaf) child, or a void child, does get its own
-- indented line -- it has internal shape worth surfacing.
#guard Node.renderPretty (Node.element .flow "div" [Node.element .flow "p" []])
  = "<div>\n  <p></p>\n</div>"
#guard Node.renderPretty (Node.element .flow "div" [(Node.voidElement .flow "hr" : Node .flow)])
  = "<div>\n  <hr>\n</div>"

-- Multiple flow children: one per line, indented one level deeper than the
-- parent, closing tag back at the parent's own indentation.
#guard Node.renderPretty
    (Node.element .flow "div" [Node.element .flow "p" [], Node.element .flow "p" []])
  = "<div>\n  <p></p>\n  <p></p>\n</div>"

-- Nesting increases indentation by one `unit` per level.
#guard Node.renderPretty
    (Node.element .flow "div"
      [Node.element .flow "div" [Node.element .flow "p" [], Node.element .flow "p" []]])
  = "<div>\n  <div>\n    <p></p>\n    <p></p>\n  </div>\n</div>"

-- Phrasing children are laid out inline, exactly like compact rendering,
-- regardless of how many there are or how deep the surrounding tree is --
-- whitespace between text/inline runs is visible in rendered output, so
-- the pretty-printer must never inject any.
#guard Node.renderPretty
    (Node.elementOf .flow .phrasing "p"
      [Node.text "Hello, ", (Node.element .phrasing "strong" [Node.text "world"] : Node .phrasing)])
  = "<p>Hello, <strong>world</strong></p>"
#guard Node.renderPretty
    (Node.element .flow "div"
      [Node.elementOf .flow .phrasing "p"
        [Node.text "Hello, ", (Node.element .phrasing "strong" [Node.text "world"] : Node .phrasing)]])
  = "<div>\n  <p>Hello, <strong>world</strong></p>\n</div>"

-- `unit` is configurable (default two spaces).
#guard Node.renderPretty (Node.element .flow "div" [Node.element .flow "p" []]) "    "
  = "<div>\n    <p></p>\n</div>"

end Tests
