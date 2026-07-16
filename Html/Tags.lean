import Html.Node
import Html.Escape
import Html.Attrs

/-!
Named tag functions, built on `Html/Node.lean`'s constructor shapes and
`Html/Attrs.lean`'s typed attribute vocabulary. See
`docs/html-library-plan.md` Phase 4 for the design rationale.

Scope notes (documented here rather than left as silent gaps):

- `html` is **not** defined here -- it's inseparable from the
  `<!DOCTYPE html>` prefix that makes it a document at all, so it stays
  `Html.document`'s sole responsibility rather than a general-purpose tag.
  `head`, `body`, `title`, `meta`, `link`, `script` *are* ordinary tags
  (below): `Html.document` no longer builds them itself -- callers compose
  them and pass the results in as `document`'s children.
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

def section_ (children : List (Node .flow)) (attrs : HtmlAttrs := {})
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

def aside (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "aside" children (combineAttrs "" attrs rawAttrs)

def hgroup (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "hgroup" children (combineAttrs "" attrs rawAttrs)

def address (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "address" children (combineAttrs "" attrs rawAttrs)

def main (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "main" children (combineAttrs "" attrs rawAttrs)

def search (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "search" children (combineAttrs "" attrs rawAttrs)

-- Document metadata/structure: ordinary flow-content tags, but only ever
-- meaningful as `Html.document`'s children (directly, or nested inside a
-- `head`/`body` of its children) -- `document` itself no longer builds
-- any of these (see module-doc scope note).
def head (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "head" children (combineAttrs "" attrs rawAttrs)

def body (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "body" children (combineAttrs "" attrs rawAttrs)

def title (content : String) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.textElement .flow "title" content (combineAttrs "" attrs rawAttrs)

/-- Void; takes `rawAttrs` as its primary content rather than a typed
attrs record, since a meta tag's shape varies by purpose --
`[("charset", "utf-8")]`, `[("name", "viewport"), ("content", "...")]`,
`[("http-equiv", "..."), ("content", "...")]`, ... -- with no one shape
common enough to single out as required fields (unlike `link`/`script`
below, which are always `rel`+`href`/`src`). -/
def meta_ (rawAttrs : List (String × String)) (attrs : HtmlAttrs := {}) : Node .flow :=
  Node.voidElement .flow "meta" (combineAttrs "" attrs rawAttrs)

def link (linkAttrs : LinkAttrs) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.voidElement .flow "link" (combineAttrs (LinkAttrs.render linkAttrs) attrs rawAttrs)

def base (baseAttrs : BaseAttrs := {}) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.voidElement .flow "base" (combineAttrs (BaseAttrs.render baseAttrs) attrs rawAttrs)

-- Not a void element (unlike `link`): `<script src="...">` still needs a
-- closing tag.
def script (scriptAttrs : ScriptAttrs) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "script" [] (combineAttrs (ScriptAttrs.render scriptAttrs) attrs rawAttrs)

-- Not a raw-text element like an inline `<script>`/`<style>` would be
-- (explicitly out of scope, see docs/html-library-plan.md Phase 0):
-- `noscript`'s content is ordinary flow-content fallback markup, not
-- script/CSS text needing different escaping.
def noscript (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "noscript" children (combineAttrs "" attrs rawAttrs)

-- Only the static markup shape is modeled, not `<template>`'s real
-- runtime semantics (inert content, `.content` fragment) -- same
-- simplification level as every other container here.
def template (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "template" children (combineAttrs "" attrs rawAttrs)

def canvas (children : List (Node .flow)) (canvasAttrs : CanvasAttrs := {})
    (attrs : HtmlAttrs := {}) (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "canvas" children (combineAttrs (CanvasAttrs.render canvasAttrs) attrs rawAttrs)

def slot (children : List (Node .phrasing)) (slotAttrs : SlotAttrs := {})
    (attrs : HtmlAttrs := {}) (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "slot" children (combineAttrs (SlotAttrs.render slotAttrs) attrs rawAttrs)

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

def menu (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "menu" children (combineAttrs "" attrs rawAttrs)

def dl (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "dl" children (combineAttrs "" attrs rawAttrs)

def dt (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "dt" children (combineAttrs "" attrs rawAttrs)

def dd (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "dd" children (combineAttrs "" attrs rawAttrs)

def blockquote (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "blockquote" children (combineAttrs "" attrs rawAttrs)

def figure (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "figure" children (combineAttrs "" attrs rawAttrs)

def figcaption (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "figcaption" children (combineAttrs "" attrs rawAttrs)

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

def span (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "span" children (combineAttrs "" attrs rawAttrs)

def i (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "i" children (combineAttrs "" attrs rawAttrs)

def b (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "b" children (combineAttrs "" attrs rawAttrs)

def u (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "u" children (combineAttrs "" attrs rawAttrs)

def s (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "s" children (combineAttrs "" attrs rawAttrs)

def mark (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "mark" children (combineAttrs "" attrs rawAttrs)

def cite (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "cite" children (combineAttrs "" attrs rawAttrs)

def dfn (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "dfn" children (combineAttrs "" attrs rawAttrs)

def abbr (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "abbr" children (combineAttrs "" attrs rawAttrs)

def var (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "var" children (combineAttrs "" attrs rawAttrs)

def samp (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "samp" children (combineAttrs "" attrs rawAttrs)

def kbd (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "kbd" children (combineAttrs "" attrs rawAttrs)

def sub (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "sub" children (combineAttrs "" attrs rawAttrs)

def sup (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "sup" children (combineAttrs "" attrs rawAttrs)

def bdi (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "bdi" children (combineAttrs "" attrs rawAttrs)

def bdo (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "bdo" children (combineAttrs "" attrs rawAttrs)

def ruby (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "ruby" children (combineAttrs "" attrs rawAttrs)

def rt (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "rt" children (combineAttrs "" attrs rawAttrs)

def rp (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "rp" children (combineAttrs "" attrs rawAttrs)

def wbr (attrs : HtmlAttrs := {}) (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.voidElement .phrasing "wbr" (combineAttrs "" attrs rawAttrs)

def q (children : List (Node .phrasing)) (qAttrs : QAttrs := {}) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "q" children (combineAttrs (QAttrs.render qAttrs) attrs rawAttrs)

def time (children : List (Node .phrasing)) (timeAttrs : TimeAttrs := {})
    (attrs : HtmlAttrs := {}) (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "time" children (combineAttrs (TimeAttrs.render timeAttrs) attrs rawAttrs)

def data (dataAttrs : DataAttrs) (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "data" children (combineAttrs (DataAttrs.render dataAttrs) attrs rawAttrs)

/-- `ins`/`del` have HTML5's "transparent" content model: each takes on
whatever category its surrounding context allows, rather than having a
fixed category of its own (`docs/html-library-plan.md` 1.1). `cat` is left
as a free, auto-bound implicit here -- exactly the same trick `Node.text`/
`Node.unsafeRaw` already use -- instead of being pinned to `.flow` or
`.phrasing` like every other tag above, since `Node.element`'s signature is
already generic over its category. This makes `ins`/`del` usable directly
inside a `<p>` (phrasing context) or a `<div>` (flow context) alike, with
no manual type ascription needed at either call site. -/
def ins (children : List (Node cat)) (insAttrs : InsDelAttrs := {}) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node cat :=
  Node.element cat "ins" children (combineAttrs (InsDelAttrs.render insAttrs) attrs rawAttrs)

def del (children : List (Node cat)) (insAttrs : InsDelAttrs := {}) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node cat :=
  Node.element cat "del" children (combineAttrs (InsDelAttrs.render insAttrs) attrs rawAttrs)

def br (attrs : HtmlAttrs := {}) (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.voidElement .phrasing "br" (combineAttrs "" attrs rawAttrs)

-- Forms: phrasing content (form controls), except `form` itself (flow).
def form (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "form" children (combineAttrs "" attrs rawAttrs)

def fieldset (children : List (Node .flow)) (fieldsetAttrs : FieldsetAttrs := {})
    (attrs : HtmlAttrs := {}) (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "fieldset" children (combineAttrs (FieldsetAttrs.render fieldsetAttrs) attrs rawAttrs)

def legend (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.elementOf .flow .phrasing "legend" children (combineAttrs "" attrs rawAttrs)

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

def datalist (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "datalist" children (combineAttrs "" attrs rawAttrs)

def optgroup (optgroupAttrs : OptgroupAttrs) (children : List (Node .phrasing))
    (attrs : HtmlAttrs := {}) (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "optgroup" children (combineAttrs (OptgroupAttrs.render optgroupAttrs) attrs rawAttrs)

def button (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "button" children (combineAttrs "" attrs rawAttrs)

def output (children : List (Node .phrasing)) (outputAttrs : OutputAttrs := {})
    (attrs : HtmlAttrs := {}) (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "output" children (combineAttrs (OutputAttrs.render outputAttrs) attrs rawAttrs)

def progress (children : List (Node .phrasing)) (progressAttrs : ProgressAttrs := {})
    (attrs : HtmlAttrs := {}) (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "progress" children (combineAttrs (ProgressAttrs.render progressAttrs) attrs rawAttrs)

def meter (children : List (Node .phrasing)) (meterAttrs : MeterAttrs := {})
    (attrs : HtmlAttrs := {}) (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.element .phrasing "meter" children (combineAttrs (MeterAttrs.render meterAttrs) attrs rawAttrs)

-- Interactive elements: flow content, flow children, except `summary`
-- (flow content, phrasing-only children, like `p`/`legend`).
def details (children : List (Node .flow)) (openAttrs : OpenAttrs := {}) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "details" children (combineAttrs (OpenAttrs.render openAttrs) attrs rawAttrs)

def summary (children : List (Node .phrasing)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.elementOf .flow .phrasing "summary" children (combineAttrs "" attrs rawAttrs)

def dialog (children : List (Node .flow)) (openAttrs : OpenAttrs := {}) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "dialog" children (combineAttrs (OpenAttrs.render openAttrs) attrs rawAttrs)

-- Media/void.
def img (imgAttrs : ImgAttrs) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .phrasing :=
  Node.voidElement .phrasing "img" (combineAttrs (ImgAttrs.render imgAttrs) attrs rawAttrs)

def hr (attrs : HtmlAttrs := {}) (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.voidElement .flow "hr" (combineAttrs "" attrs rawAttrs)

-- Embedded content: flow content, flow children, holding `source`/`track`
-- void children (also flow, for use inside them) alongside fallback
-- markup -- same "container accepts general flow children" simplification
-- as `ul`/`ol`/`table` (module doc above).
def picture (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "picture" children (combineAttrs "" attrs rawAttrs)

def source (sourceAttrs : SourceAttrs := {}) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.voidElement .flow "source" (combineAttrs (SourceAttrs.render sourceAttrs) attrs rawAttrs)

def track (trackAttrs : TrackAttrs) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.voidElement .flow "track" (combineAttrs (TrackAttrs.render trackAttrs) attrs rawAttrs)

def iframe (iframeAttrs : IframeAttrs) (children : List (Node .flow) := [])
    (attrs : HtmlAttrs := {}) (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "iframe" children (combineAttrs (IframeAttrs.render iframeAttrs) attrs rawAttrs)

def embed (embedAttrs : EmbedAttrs := {}) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.voidElement .flow "embed" (combineAttrs (EmbedAttrs.render embedAttrs) attrs rawAttrs)

def object (objectAttrs : ObjectAttrs := {}) (children : List (Node .flow) := [])
    (attrs : HtmlAttrs := {}) (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "object" children (combineAttrs (ObjectAttrs.render objectAttrs) attrs rawAttrs)

def video (children : List (Node .flow) := []) (videoAttrs : VideoAttrs := {})
    (attrs : HtmlAttrs := {}) (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "video" children (combineAttrs (VideoAttrs.render videoAttrs) attrs rawAttrs)

def audio (children : List (Node .flow) := []) (audioAttrs : AudioAttrs := {})
    (attrs : HtmlAttrs := {}) (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "audio" children (combineAttrs (AudioAttrs.render audioAttrs) attrs rawAttrs)

def map (mapAttrs : MapAttrs) (children : List (Node .flow) := [])
    (attrs : HtmlAttrs := {}) (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "map" children (combineAttrs (MapAttrs.render mapAttrs) attrs rawAttrs)

def area (areaAttrs : AreaAttrs := {}) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.voidElement .flow "area" (combineAttrs (AreaAttrs.render areaAttrs) attrs rawAttrs)

-- Table: flow content, flow children (see module-doc note on not
-- enforcing HTML5's stricter table content model).
def table (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "table" children (combineAttrs "" attrs rawAttrs)

def caption (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "caption" children (combineAttrs "" attrs rawAttrs)

def colgroup (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "colgroup" children (combineAttrs "" attrs rawAttrs)

def col (colAttrs : ColAttrs := {}) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.voidElement .flow "col" (combineAttrs (ColAttrs.render colAttrs) attrs rawAttrs)

def thead (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "thead" children (combineAttrs "" attrs rawAttrs)

def tbody (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "tbody" children (combineAttrs "" attrs rawAttrs)

def tfoot (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "tfoot" children (combineAttrs "" attrs rawAttrs)

def tr (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "tr" children (combineAttrs "" attrs rawAttrs)

def th (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "th" children (combineAttrs "" attrs rawAttrs)

def td (children : List (Node .flow)) (attrs : HtmlAttrs := {})
    (rawAttrs : List (String × String) := []) : Node .flow :=
  Node.element .flow "td" children (combineAttrs "" attrs rawAttrs)

end Html
