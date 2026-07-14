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

end Html
