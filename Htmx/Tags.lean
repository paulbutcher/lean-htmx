import Html
import Htmx.Attrs

/-!
Thin htmx wrapper tags, one per `Html/Tags.lean` tag. See
`docs/html-library-plan.md` 1.4 (the mechanism this validates) and Phase 6.

Each wrapper here has exactly the same signature as the matching
`Html.*` tag, plus one extra typed `hx : HtmxAttrs := {}` parameter. `hx` is
never part of `Html.Node`'s type -- an `Htmx.div`'s result is a plain
`Html.Node .flow`, identical to what `Html.div` produces, so it composes
freely with the rest of `Html` (no `Coe`/reinterpretation needed, unlike
1.5's rejected mechanism). Internally, every wrapper just flattens `hx` via
`HtmxAttrs.toPairs` and prepends it to the caller's own `rawAttrs`, then
forwards to the matching `Html.*` function -- `Html.lean` needed **zero**
changes for this to work.
-/

namespace Htmx

-- Structure: flow content, flow children.
def div (children : List (Html.Node .flow)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.div children attrs (hx.toPairs ++ rawAttrs)

def «section» (children : List (Html.Node .flow)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.section children attrs (hx.toPairs ++ rawAttrs)

def article (children : List (Html.Node .flow)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.article children attrs (hx.toPairs ++ rawAttrs)

def header (children : List (Html.Node .flow)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.header children attrs (hx.toPairs ++ rawAttrs)

def footer (children : List (Html.Node .flow)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.footer children attrs (hx.toPairs ++ rawAttrs)

def nav (children : List (Html.Node .flow)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.nav children attrs (hx.toPairs ++ rawAttrs)

-- Text: flow content, phrasing-only children.
def p (children : List (Html.Node .phrasing)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.p children attrs (hx.toPairs ++ rawAttrs)

def h1 (children : List (Html.Node .phrasing)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.h1 children attrs (hx.toPairs ++ rawAttrs)

def h2 (children : List (Html.Node .phrasing)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.h2 children attrs (hx.toPairs ++ rawAttrs)

def h3 (children : List (Html.Node .phrasing)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.h3 children attrs (hx.toPairs ++ rawAttrs)

def h4 (children : List (Html.Node .phrasing)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.h4 children attrs (hx.toPairs ++ rawAttrs)

def h5 (children : List (Html.Node .phrasing)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.h5 children attrs (hx.toPairs ++ rawAttrs)

def h6 (children : List (Html.Node .phrasing)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.h6 children attrs (hx.toPairs ++ rawAttrs)

-- Text: flow content, flow children.
def ul (children : List (Html.Node .flow)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.ul children attrs (hx.toPairs ++ rawAttrs)

def ol (children : List (Html.Node .flow)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.ol children attrs (hx.toPairs ++ rawAttrs)

def li (children : List (Html.Node .flow)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.li children attrs (hx.toPairs ++ rawAttrs)

def blockquote (children : List (Html.Node .flow)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.blockquote children attrs (hx.toPairs ++ rawAttrs)

def pre (children : List (Html.Node .phrasing)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.pre children attrs (hx.toPairs ++ rawAttrs)

def code (children : List (Html.Node .phrasing)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.code children attrs (hx.toPairs ++ rawAttrs)

-- Inline.
def a (linkAttrs : Html.AAttrs) (children : List (Html.Node .phrasing)) (hx : HtmxAttrs := {})
    (attrs : Html.HtmlAttrs := {}) (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.a linkAttrs children attrs (hx.toPairs ++ rawAttrs)

def strong (children : List (Html.Node .phrasing)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.strong children attrs (hx.toPairs ++ rawAttrs)

def em (children : List (Html.Node .phrasing)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.em children attrs (hx.toPairs ++ rawAttrs)

def small (children : List (Html.Node .phrasing)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.small children attrs (hx.toPairs ++ rawAttrs)

def br (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.br attrs (hx.toPairs ++ rawAttrs)

-- Forms.
def form (children : List (Html.Node .flow)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.form children attrs (hx.toPairs ++ rawAttrs)

def input (inputAttrs : Html.InputAttrs := {}) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.input inputAttrs attrs (hx.toPairs ++ rawAttrs)

def label (children : List (Html.Node .phrasing)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.label children attrs (hx.toPairs ++ rawAttrs)

def textarea (content : String) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.textarea content attrs (hx.toPairs ++ rawAttrs)

def option (label : String) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.option label attrs (hx.toPairs ++ rawAttrs)

def select (children : List (Html.Node .phrasing)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.select children attrs (hx.toPairs ++ rawAttrs)

def button (children : List (Html.Node .phrasing)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.button children attrs (hx.toPairs ++ rawAttrs)

-- Media/void.
def img (imgAttrs : Html.ImgAttrs) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.img imgAttrs attrs (hx.toPairs ++ rawAttrs)

def hr (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.hr attrs (hx.toPairs ++ rawAttrs)

-- Table.
def table (children : List (Html.Node .flow)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.table children attrs (hx.toPairs ++ rawAttrs)

def thead (children : List (Html.Node .flow)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.thead children attrs (hx.toPairs ++ rawAttrs)

def tbody (children : List (Html.Node .flow)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.tbody children attrs (hx.toPairs ++ rawAttrs)

def tr (children : List (Html.Node .flow)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.tr children attrs (hx.toPairs ++ rawAttrs)

def th (children : List (Html.Node .flow)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.th children attrs (hx.toPairs ++ rawAttrs)

def td (children : List (Html.Node .flow)) (hx : HtmxAttrs := {}) (attrs : Html.HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.td children attrs (hx.toPairs ++ rawAttrs)

-- #guard smoke test per tag: hx attributes render as ordinary rawAttrs,
-- and the result is a plain Html.Node -- fully interoperable with Html's
-- own tag functions (e.g. the `p`/`strong` nesting below).
#guard Html.Node.render (div [] { hxGet := some "/x" }) = "<div hx-get=\"/x\"></div>"
#guard Html.Node.render (button [Html.Node.text "Go"] { hxPost := some "/go", hxTarget := some "#r" })
  = "<button hx-post=\"/go\" hx-target=\"#r\">Go</button>"
#guard Html.Node.render (a { href := "#" } [] { hxGet := some "/x" }) = "<a href=\"#\" hx-get=\"/x\"></a>"
#guard Html.Node.render (input { type := "text" } { hxGet := some "/search", hxTrigger := some "keyup" })
  = "<input type=\"text\" hx-get=\"/search\" hx-trigger=\"keyup\">"
#guard Html.Node.render (form [] { hxPost := some "/submit" }) = "<form hx-post=\"/submit\"></form>"
#guard Html.Node.render (img { src := "a.png", alt := "d" } { hxGet := some "/refresh" })
  = "<img src=\"a.png\" alt=\"d\" hx-get=\"/refresh\">"
#guard Html.Node.render (textarea "hi" { hxTrigger := some "change" })
  = "<textarea hx-trigger=\"change\">hi</textarea>"
#guard Html.Node.render (option "hi" { hxGet := some "/x" }) = "<option hx-get=\"/x\">hi</option>"
#guard Html.Node.render (br) = "<br>"
#guard Html.Node.render (hr { hxGet := some "/x" }) = "<hr hx-get=\"/x\">"
#guard Html.Node.render (tr [td [] { hxGet := some "/x" }]) = "<tr><td hx-get=\"/x\"></td></tr>"

-- Composition: an Htmx tag nests inside a plain Html tag and vice versa --
-- `hx` never leaks into `Node`'s type (1.4), so both directions typecheck.
#guard Html.Node.render (Html.div [div [] { hxGet := some "/x" }])
  = "<div><div hx-get=\"/x\"></div></div>"
#guard Html.Node.render (div [Html.p [Html.Node.text "hi"]] { hxGet := some "/x" })
  = "<div hx-get=\"/x\"><p>hi</p></div>"

-- attrs/rawAttrs still compose alongside hx, same as every Html tag --
-- attrs (HtmlAttrs) render before hx/rawAttrs, since hx is folded into the
-- `rawAttrs` argument forwarded to `Html.div`, positionally after `attrs`.
#guard Html.Node.render (div [] { hxGet := some "/x" } { id := some "y" } [("data-z", "1")])
  = "<div id=\"y\" hx-get=\"/x\" data-z=\"1\"></div>"

end Htmx
