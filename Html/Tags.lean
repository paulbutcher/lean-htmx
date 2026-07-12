import Html.Node
import Html.Escape
import Html.Attrs

/-!
Named tag functions, built on `Html/Node.lean`'s constructor shapes and
`Html/Attrs.lean`'s typed attribute vocabulary. See
`docs/html-library-plan.md` Phase 4 for the design rationale.

Scope notes (documented here rather than left as silent gaps):

- `html`, `head`, `body`, `meta`, `link` are **not** defined here -- per
  Phase 0's Category-lattice decision, they're handled as a special case
  of Phase 5's document skeleton (`Html.document`), not as general-purpose
  reusable tags.
- Only `AAttrs`, `ImgAttrs`, `InputAttrs` (Phase 3) get dedicated typed
  attribute records. Every other tag below takes plain `HtmlAttrs` (global
  attributes only) plus `rawAttrs` -- element-specific attributes beyond
  those three examples (`form`'s `action`/`method`, `button`'s `disabled`,
  `select`'s `multiple`, `label`'s `for`, ...) are not modeled as typed
  fields yet; use `rawAttrs` for them. This keeps the attribute vocabulary
  consistent rather than ad hoc per tag; more typed records can be added
  later following `AAttrs`/`ImgAttrs`/`InputAttrs`'s pattern.
- Only `flow`/`phrasing` are modeled (Phase 0), so container elements with
  a stricter HTML5 content model than "some flow content" -- `ul`/`ol`
  (only `<li>`), `table`/`thead`/`tbody`/`tr` (only specific row/cell
  children), `select` (only `<option>`) -- accept general flow or phrasing
  children here rather than enforcing the narrower real-world constraint.
  That fidelity is Phase 6 scope ("broader `Category` lattice").
-/

namespace Html

private def combineAttrs (specific : String) (attrs : HtmlAttrs) (rawAttrs : List (String × String)) : String :=
  specific ++ HtmlAttrs.render attrs ++ renderRawAttrs rawAttrs

-- Structure: flow content, flow children.
def div (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "div" children (combineAttrs "" attrs rawAttrs)

def «section» (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "section" children (combineAttrs "" attrs rawAttrs)

def article (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "article" children (combineAttrs "" attrs rawAttrs)

def header (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "header" children (combineAttrs "" attrs rawAttrs)

def footer (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "footer" children (combineAttrs "" attrs rawAttrs)

def nav (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "nav" children (combineAttrs "" attrs rawAttrs)

-- Text: flow content, phrasing-only children (a `<div>` inside these is a
-- type error, not just an HTML validity error).
def p (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.elementOf .flow .phrasing "p" children (combineAttrs "" attrs rawAttrs)

def h1 (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.elementOf .flow .phrasing "h1" children (combineAttrs "" attrs rawAttrs)

def h2 (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.elementOf .flow .phrasing "h2" children (combineAttrs "" attrs rawAttrs)

def h3 (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.elementOf .flow .phrasing "h3" children (combineAttrs "" attrs rawAttrs)

def h4 (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.elementOf .flow .phrasing "h4" children (combineAttrs "" attrs rawAttrs)

def h5 (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.elementOf .flow .phrasing "h5" children (combineAttrs "" attrs rawAttrs)

def h6 (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.elementOf .flow .phrasing "h6" children (combineAttrs "" attrs rawAttrs)

-- Text: flow content, flow children (list/quote/preformatted containers;
-- see the module-doc note on `ul`/`ol` not enforcing "only `<li>`").
def ul (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "ul" children (combineAttrs "" attrs rawAttrs)

def ol (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "ol" children (combineAttrs "" attrs rawAttrs)

def li (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "li" children (combineAttrs "" attrs rawAttrs)

def blockquote (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "blockquote" children (combineAttrs "" attrs rawAttrs)

-- `pre`: flow content, phrasing-only children (preformatted text).
def pre (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.elementOf .flow .phrasing "pre" children (combineAttrs "" attrs rawAttrs)

-- `code`: phrasing content, phrasing children.
def code (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "code" children (combineAttrs "" attrs rawAttrs)

-- Inline: phrasing content, phrasing children.
def a (linkAttrs : AAttrs) (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "a" children (combineAttrs (AAttrs.render linkAttrs) attrs rawAttrs)

def strong (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "strong" children (combineAttrs "" attrs rawAttrs)

def em (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "em" children (combineAttrs "" attrs rawAttrs)

def small (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "small" children (combineAttrs "" attrs rawAttrs)

def br (attrs : HtmlAttrs := {}) (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.voidElement .phrasing "br" (combineAttrs "" attrs rawAttrs)

-- Forms: phrasing content (form controls), except `form` itself (flow).
def form (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "form" children (combineAttrs "" attrs rawAttrs)

def input (inputAttrs : InputAttrs := {}) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.voidElement .phrasing "input" (combineAttrs (InputAttrs.render inputAttrs) attrs rawAttrs)

def label (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "label" children (combineAttrs "" attrs rawAttrs)

-- `textarea`/`option`: text content model, not nested elements (RCDATA-like).
def textarea (content : String) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.textElement .phrasing "textarea" content (combineAttrs "" attrs rawAttrs)

def option (label : String) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.textElement .phrasing "option" label (combineAttrs "" attrs rawAttrs)

def select (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "select" children (combineAttrs "" attrs rawAttrs)

def button (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "button" children (combineAttrs "" attrs rawAttrs)

-- Media/void.
def img (imgAttrs : ImgAttrs) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.voidElement .phrasing "img" (combineAttrs (ImgAttrs.render imgAttrs) attrs rawAttrs)

def hr (attrs : HtmlAttrs := {}) (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.voidElement .flow "hr" (combineAttrs "" attrs rawAttrs)

-- Table: flow content, flow children (see module-doc note on not
-- enforcing HTML5's stricter table content model).
def table (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "table" children (combineAttrs "" attrs rawAttrs)

def thead (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "thead" children (combineAttrs "" attrs rawAttrs)

def tbody (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "tbody" children (combineAttrs "" attrs rawAttrs)

def tr (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "tr" children (combineAttrs "" attrs rawAttrs)

def th (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "th" children (combineAttrs "" attrs rawAttrs)

def td (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "td" children (combineAttrs "" attrs rawAttrs)

-- #guard smoke test per tag: minimal render output, no attrs.
#guard Node.render (div []) = "<div></div>"
#guard Node.render («section» []) = "<section></section>"
#guard Node.render (article []) = "<article></article>"
#guard Node.render (header []) = "<header></header>"
#guard Node.render (footer []) = "<footer></footer>"
#guard Node.render (nav []) = "<nav></nav>"
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
#guard Node.render (blockquote []) = "<blockquote></blockquote>"
#guard Node.render (pre []) = "<pre></pre>"
#guard Node.render (code []) = "<code></code>"
#guard Node.render (a { href := "x" } []) = "<a href=\"x\"></a>"
#guard Node.render (strong []) = "<strong></strong>"
#guard Node.render (em []) = "<em></em>"
#guard Node.render (small []) = "<small></small>"
#guard Node.render (br) = "<br>"
#guard Node.render (form []) = "<form></form>"
#guard Node.render (input) = "<input type=\"text\">"
#guard Node.render (label []) = "<label></label>"
#guard Node.render (textarea "hi") = "<textarea>hi</textarea>"
#guard Node.render (option "hi") = "<option>hi</option>"
#guard Node.render (select []) = "<select></select>"
#guard Node.render (button []) = "<button></button>"
#guard Node.render (img { src := "a.png", alt := "d" }) = "<img src=\"a.png\" alt=\"d\">"
#guard Node.render (hr) = "<hr>"
#guard Node.render (table []) = "<table></table>"
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
#guard Node.render (div [] { id := some "x", class_ := some "y" })
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

end Html
