import Html
import Htmx.Attrs

/-!
Thin htmx wrapper tags, one per `Html/Tags.lean` tag. Each has exactly the
same signature as the matching `Html.*` tag -- a single `attrs` argument
(`HtmxAttrs`, or a `Htmx.<Tag>Attrs` merging the element's own `Html.<Tag>Attrs`
with `HtmxAttrs`) plus `rawAttrs`.
-/

namespace Htmx

-- Structure: flow content, flow children.
def div (children : List (Html.Node .flow)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.div children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

def section_ (children : List (Html.Node .flow)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.section_ children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

def article (children : List (Html.Node .flow)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.article children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

def header (children : List (Html.Node .flow)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.header children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

def footer (children : List (Html.Node .flow)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.footer children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

def nav (children : List (Html.Node .flow)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.nav children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

-- Text: flow content, phrasing-only children.
def p (children : List (Html.Node .phrasing)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.p children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

def h1 (children : List (Html.Node .phrasing)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.h1 children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

def h2 (children : List (Html.Node .phrasing)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.h2 children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

def h3 (children : List (Html.Node .phrasing)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.h3 children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

def h4 (children : List (Html.Node .phrasing)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.h4 children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

def h5 (children : List (Html.Node .phrasing)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.h5 children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

def h6 (children : List (Html.Node .phrasing)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.h6 children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

-- Text: flow content, flow children.
def ul (children : List (Html.Node .listItem)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.ul children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

def ol (children : List (Html.Node .listItem)) (attrs : OlAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.ol children attrs.toOlAttrs (attrs.toHtmxAttrs.toPairs ++ rawAttrs)

def li (children : List (Html.Node .flow)) (attrs : LiAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .listItem :=
  Html.li children attrs.toLiAttrs (attrs.toHtmxAttrs.toPairs ++ rawAttrs)

def blockquote (children : List (Html.Node .flow)) (attrs : BlockquoteAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.blockquote children attrs.toBlockquoteAttrs (attrs.toHtmxAttrs.toPairs ++ rawAttrs)

def pre (children : List (Html.Node .phrasing)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.pre children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

def code (children : List (Html.Node .phrasing)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.code children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

-- Inline.
def a (attrs : AAttrs) (children : List (Html.Node .phrasing))
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.a attrs.toAAttrs children (attrs.toHtmxAttrs.toPairs ++ rawAttrs)

def strong (children : List (Html.Node .phrasing)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.strong children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

def em (children : List (Html.Node .phrasing)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.em children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

def small (children : List (Html.Node .phrasing)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.small children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

def br (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.br attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

-- Forms.
def form (children : List (Html.Node .flow)) (attrs : FormAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.form children attrs.toFormAttrs (attrs.toHtmxAttrs.toPairs ++ rawAttrs)

def input (attrs : InputAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.input attrs.toInputAttrs (attrs.toHtmxAttrs.toPairs ++ rawAttrs)

def label (children : List (Html.Node .phrasing)) (attrs : LabelAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.label children attrs.toLabelAttrs (attrs.toHtmxAttrs.toPairs ++ rawAttrs)

def textarea (content : String) (attrs : TextareaAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.textarea content attrs.toTextareaAttrs (attrs.toHtmxAttrs.toPairs ++ rawAttrs)

def option (label : String) (attrs : OptionAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .option :=
  Html.option label attrs.toOptionAttrs (attrs.toHtmxAttrs.toPairs ++ rawAttrs)

def select (children : List (Html.Node .selectChild)) (attrs : SelectAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.select children attrs.toSelectAttrs (attrs.toHtmxAttrs.toPairs ++ rawAttrs)

def button (children : List (Html.Node .phrasing)) (attrs : ButtonAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.button children attrs.toButtonAttrs (attrs.toHtmxAttrs.toPairs ++ rawAttrs)

-- Media/void.
def img (attrs : ImgAttrs)
    (rawAttrs : List (String × String) := []) : Html.Node .phrasing :=
  Html.img attrs.toImgAttrs (attrs.toHtmxAttrs.toPairs ++ rawAttrs)

def hr (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.hr attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

-- Table.
def table (children : List (Html.Node .tableSection)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .flow :=
  Html.table children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

def thead (children : List (Html.Node .tableRow)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .tableSection :=
  Html.thead children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

def tbody (children : List (Html.Node .tableRow)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .tableSection :=
  Html.tbody children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

def tr (children : List (Html.Node .tableCell)) (attrs : HtmxAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .tableRow :=
  Html.tr children attrs.toHtmlAttrs (attrs.toPairs ++ rawAttrs)

def th (children : List (Html.Node .flow)) (attrs : ThAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .tableCell :=
  Html.th children attrs.toThAttrs (attrs.toHtmxAttrs.toPairs ++ rawAttrs)

def td (children : List (Html.Node .flow)) (attrs : TdAttrs := {})
    (rawAttrs : List (String × String) := []) : Html.Node .tableCell :=
  Html.td children attrs.toTdAttrs (attrs.toHtmxAttrs.toPairs ++ rawAttrs)

end Htmx
