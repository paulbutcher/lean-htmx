import Html.Escape

/-!
Typed attribute vocabulary and rendering. See `docs/html-library-plan.md`
Phase 3 for the design rationale. Not yet wired into `Node`/tag functions
-- that's Phase 4, once the tag functions exist to accept these as
parameters.
-/

namespace Html

/-- Render a boolean attribute: the bare attribute name when `true`,
absent entirely when `false` -- HTML5 boolean-attribute semantics treat
*any* value (including `"false"`) as present, so `name="false"` would be
wrong, not just ugly. Not a corollary of anything else in this library;
an explicit decision (`docs/html-library-plan.md` Phase 3). -/
def renderBoolAttr (name : String) : Bool → String
  | true => s!" {name}"
  | false => ""

/-- Render one optional string-valued attribute: escaped and
double-quote-delimited via `renderAttr` when present, empty when absent. -/
private def renderOpt (name : String) : Option String → String
  | none => ""
  | some v => renderAttr name v

/-- Render arbitrary `(name, value)` pairs verbatim: values escaped, names
*not* validated. See `docs/html-library-plan.md` 1.3 for why this
asymmetry is intentional (names are assumed to always be literal
source-code identifiers) and the `#guard` below for a test that documents
the gap rather than closing it. -/
def renderRawAttrs (attrs : List (String × String)) : String :=
  String.join (attrs.map (fun (n, v) => renderAttr n v))

/-- Global attributes, valid on any element. `class_` (not `class`, a
Lean keyword) renders as the `class` attribute. -/
structure HtmlAttrs where
  id : Option String := none
  class_ : Option String := none
  style : Option String := none
  title : Option String := none
  lang : Option String := none
  dir : Option String := none

def HtmlAttrs.render (a : HtmlAttrs) : String :=
  renderOpt "id" a.id ++ renderOpt "class" a.class_ ++ renderOpt "style" a.style ++
    renderOpt "title" a.title ++ renderOpt "lang" a.lang ++ renderOpt "dir" a.dir

/-- Typed attributes for `<a>`. `href` is required -- an anchor without
one isn't a hyperlink. Stays plain `String` for v1, not a dedicated URL
type: see `docs/html-library-plan.md` 1.3. -/
structure AAttrs where
  href : String
  target : Option String := none
  rel : Option String := none

def AAttrs.render (a : AAttrs) : String :=
  renderAttr "href" a.href ++ renderOpt "target" a.target ++ renderOpt "rel" a.rel

/-- Typed attributes for `<img>`. Both `src` and `alt` are required --
`alt` for accessibility, not just HTML validity. -/
structure ImgAttrs where
  src : String
  alt : String

def ImgAttrs.render (a : ImgAttrs) : String :=
  renderAttr "src" a.src ++ renderAttr "alt" a.alt

/-- Typed attributes for `<input>`. `type` stays plain `String`, not a
closed enum, for v1 (deferred, not a silent gap -- see
`docs/html-library-plan.md` Phase 0 scope). `disabled`/`checked`/
`required`/`readonly` follow the boolean-attribute rule above. -/
structure InputAttrs where
  type : String := "text"
  name : Option String := none
  value : Option String := none
  placeholder : Option String := none
  disabled : Bool := false
  checked : Bool := false
  required : Bool := false
  readonly : Bool := false

def InputAttrs.render (a : InputAttrs) : String :=
  renderAttr "type" a.type ++ renderOpt "name" a.name ++ renderOpt "value" a.value ++
    renderOpt "placeholder" a.placeholder ++ renderBoolAttr "disabled" a.disabled ++
    renderBoolAttr "checked" a.checked ++ renderBoolAttr "required" a.required ++
    renderBoolAttr "readonly" a.readonly

-- #guard tests, one (or more) per attribute.
#guard HtmlAttrs.render {} = ""
#guard HtmlAttrs.render { id := some "x" } = " id=\"x\""
#guard HtmlAttrs.render { class_ := some "a b" } = " class=\"a b\""
#guard HtmlAttrs.render { style := some "color:red" } = " style=\"color:red\""
#guard HtmlAttrs.render { title := some "t" } = " title=\"t\""
#guard HtmlAttrs.render { lang := some "en" } = " lang=\"en\""
#guard HtmlAttrs.render { dir := some "ltr" } = " dir=\"ltr\""
#guard HtmlAttrs.render { id := some "x", class_ := some "y" } = " id=\"x\" class=\"y\""
#guard HtmlAttrs.render { id := some "x\"y" } = " id=\"x&quot;y\""  -- values still escaped

#guard AAttrs.render { href := "https://example.com" } = " href=\"https://example.com\""
#guard AAttrs.render { href := "x", target := some "_blank" } = " href=\"x\" target=\"_blank\""

#guard ImgAttrs.render { src := "a.png", alt := "desc" } = " src=\"a.png\" alt=\"desc\""

#guard InputAttrs.render {} = " type=\"text\""
#guard InputAttrs.render { disabled := true } = " type=\"text\" disabled"
#guard InputAttrs.render { disabled := false } = " type=\"text\""  -- explicit: never `disabled="false"`
#guard InputAttrs.render { checked := true, required := true } = " type=\"text\" checked required"
#guard InputAttrs.render { name := some "q", value := some "v" } = " type=\"text\" name=\"q\" value=\"v\""

#guard renderBoolAttr "disabled" true = " disabled"
#guard renderBoolAttr "disabled" false = ""

-- rawAttrs: values are escaped, but names are intentionally NOT validated
-- (documenting the gap, not fixing it -- see docs/html-library-plan.md 1.3).
#guard renderRawAttrs [("data-x", "a\"b")] = " data-x=\"a&quot;b\""
#guard renderRawAttrs [("hx-get", "/x"), ("hx-target", "#y")] = " hx-get=\"/x\" hx-target=\"#y\""
#guard renderRawAttrs [("evil onmouseover=\"alert(1)", "x")]
  = " evil onmouseover=\"alert(1)=\"x\""  -- a space in the name breaks out of the tag; unchecked by design

end Html
