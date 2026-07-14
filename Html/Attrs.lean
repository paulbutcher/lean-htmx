import Html.Escape

/-!
Typed attribute vocabulary and rendering. See `docs/html-library-plan.md`
Phase 3 for the design rationale. Not yet wired into `Node`/tag functions
-- that's Phase 4, once the tag functions exist to accept these as
parameters.
-/

namespace Html

/-- Lets `{ id := "x" }` elaborate directly against an `Option String`
field without writing `some "x"` -- every optional attribute field in this
file is `Option String`, so without this every struct literal that sets
one is `some`-noise. Scoped to `Html` so it only fires for code that
opens/is inside this namespace, not any `Option String` anywhere.
Deliberately *not* the same shape as the `Coe (Node .phrasing) (Node
.flow)` friction in `docs/html-library-plan.md` 1.2: that broke because
the coercion shared an unresolved metavariable (the phantom `Category`/`α`
index) between source and target. Here both sides are fully concrete, so
there's no metavariable for coercion insertion to choke on -- confirmed by
spike, including that a genuine type error (e.g. `id := true`) still
produces a plain, direct message rather than 1.2's opaque one (see
`#guard_msgs` example below). -/
scoped instance : Coe String (Option String) := ⟨some⟩

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

/-- Typed attributes for an external `<script src="...">` tag (used by
`Html.script`, e.g. for loading a library from a CDN). `integrity`/
`crossorigin` carry Subresource Integrity metadata -- load-bearing for a
CDN-hosted script (it's what lets the browser refuse a tampered file
instead of silently running it), not decorative, so they're modeled
explicitly here rather than left to the `rawAttrs` escape hatch. -/
structure ScriptAttrs where
  src : String
  integrity : Option String := none
  crossorigin : Option String := none

def ScriptAttrs.render (a : ScriptAttrs) : String :=
  renderAttr "src" a.src ++ renderOpt "integrity" a.integrity ++ renderOpt "crossorigin" a.crossorigin

/-- Typed attributes for `<link>`. `rel` and `href` are both required --
a `<link>` with neither states nothing (most commonly `rel="stylesheet"`,
but also `rel="icon"`, `rel="preload"`, ...). -/
structure LinkAttrs where
  rel : String
  href : String

def LinkAttrs.render (a : LinkAttrs) : String :=
  renderAttr "rel" a.rel ++ renderAttr "href" a.href

/-- Typed attributes for `<q>`. `cite` is the (optional) URL of a source
document/message explaining the quote. -/
structure QAttrs where
  cite : Option String := none

def QAttrs.render (a : QAttrs) : String :=
  renderOpt "cite" a.cite

/-- Typed attributes for `<time>`. `datetime` is the machine-readable
equivalent of the element's human-readable text content. -/
structure TimeAttrs where
  datetime : Option String := none

def TimeAttrs.render (a : TimeAttrs) : String :=
  renderOpt "datetime" a.datetime

/-- Typed attributes for `<data>`. `value` (required) is the
machine-readable equivalent of the element's human-readable text
content. -/
structure DataAttrs where
  value : String

def DataAttrs.render (a : DataAttrs) : String :=
  renderAttr "value" a.value

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

/-- Typed attributes for `<ins>`/`<del>`. `cite` is the (optional) URL of a
source document/message explaining the edit; `datetime` is the (optional)
machine-readable time the edit was made. -/
structure InsDelAttrs where
  cite : Option String := none
  datetime : Option String := none

def InsDelAttrs.render (a : InsDelAttrs) : String :=
  renderOpt "cite" a.cite ++ renderOpt "datetime" a.datetime

#guard InsDelAttrs.render {} = ""
#guard InsDelAttrs.render { cite := "https://example.com", datetime := "2026-07-14" }
  = " cite=\"https://example.com\" datetime=\"2026-07-14\""

/-- Typed attributes for `<col>`. `span` (optional) is the number of
columns the element represents -- stays plain `String` for v1, same
decision as every other value-bearing attribute (see 1.3). -/
structure ColAttrs where
  span : Option String := none

def ColAttrs.render (a : ColAttrs) : String :=
  renderOpt "span" a.span

#guard ColAttrs.render {} = ""
#guard ColAttrs.render { span := "2" } = " span=\"2\""

/-- Typed attributes for `<fieldset>`. -/
structure FieldsetAttrs where
  disabled : Bool := false
  name : Option String := none

def FieldsetAttrs.render (a : FieldsetAttrs) : String :=
  renderBoolAttr "disabled" a.disabled ++ renderOpt "name" a.name

#guard FieldsetAttrs.render {} = ""
#guard FieldsetAttrs.render { disabled := true, name := "x" } = " disabled name=\"x\""

/-- Typed attributes for `<optgroup>`. `label` is required -- an optgroup
without one has nothing to show as its group heading. -/
structure OptgroupAttrs where
  label : String
  disabled : Bool := false

def OptgroupAttrs.render (a : OptgroupAttrs) : String :=
  renderAttr "label" a.label ++ renderBoolAttr "disabled" a.disabled

#guard OptgroupAttrs.render { label := "Fruit" } = " label=\"Fruit\""
#guard OptgroupAttrs.render { label := "Fruit", disabled := true } = " label=\"Fruit\" disabled"

/-- Typed attributes for `<output>`. `for_` (trailing underscore -- `for`
is a Lean keyword, same reason as `class_`/`section_`) is the
space-separated list of ids of elements the output's value is calculated
from. -/
structure OutputAttrs where
  for_ : Option String := none
  name : Option String := none

def OutputAttrs.render (a : OutputAttrs) : String :=
  renderOpt "for" a.for_ ++ renderOpt "name" a.name

#guard OutputAttrs.render {} = ""
#guard OutputAttrs.render { for_ := "a b", name := "result" } = " for=\"a b\" name=\"result\""

/-- Typed attributes for `<progress>`. Both stay plain `Option String`,
same "value-bearing attributes stay `String` for v1" decision as
elsewhere (1.3) -- no numeric type introduced just for these two fields. -/
structure ProgressAttrs where
  value : Option String := none
  max : Option String := none

def ProgressAttrs.render (a : ProgressAttrs) : String :=
  renderOpt "value" a.value ++ renderOpt "max" a.max

#guard ProgressAttrs.render {} = ""
#guard ProgressAttrs.render { value := "50", max := "100" } = " value=\"50\" max=\"100\""

/-- Typed attributes for `<meter>`. -/
structure MeterAttrs where
  value : Option String := none
  min : Option String := none
  max : Option String := none
  low : Option String := none
  high : Option String := none
  optimum : Option String := none

def MeterAttrs.render (a : MeterAttrs) : String :=
  renderOpt "value" a.value ++ renderOpt "min" a.min ++ renderOpt "max" a.max ++
    renderOpt "low" a.low ++ renderOpt "high" a.high ++ renderOpt "optimum" a.optimum

#guard MeterAttrs.render {} = ""
#guard MeterAttrs.render { value := "6", min := "0", max := "10" }
  = " value=\"6\" min=\"0\" max=\"10\""

/-- Typed attributes shared by `<details>`/`<dialog>`. `open_` (trailing
underscore -- `open` is a Lean keyword, same reason as `class_`/`section_`/
`for_`) is the single boolean attribute both elements have. -/
structure OpenAttrs where
  open_ : Bool := false

def OpenAttrs.render (a : OpenAttrs) : String :=
  renderBoolAttr "open" a.open_

#guard OpenAttrs.render {} = ""
#guard OpenAttrs.render { open_ := true } = " open"

/-- Typed attributes for `<base>`. Both fields are independently optional
-- a document typically sets one or the other (or both), not necessarily
either. -/
structure BaseAttrs where
  href : Option String := none
  target : Option String := none

def BaseAttrs.render (a : BaseAttrs) : String :=
  renderOpt "href" a.href ++ renderOpt "target" a.target

#guard BaseAttrs.render {} = ""
#guard BaseAttrs.render { href := "/", target := "_blank" } = " href=\"/\" target=\"_blank\""

/-- Typed attributes for `<canvas>`. -/
structure CanvasAttrs where
  width : Option String := none
  height : Option String := none

def CanvasAttrs.render (a : CanvasAttrs) : String :=
  renderOpt "width" a.width ++ renderOpt "height" a.height

#guard CanvasAttrs.render {} = ""
#guard CanvasAttrs.render { width := "300", height := "150" } = " width=\"300\" height=\"150\""

/-- Typed attributes for `<slot>`. -/
structure SlotAttrs where
  name : Option String := none

def SlotAttrs.render (a : SlotAttrs) : String :=
  renderOpt "name" a.name

#guard SlotAttrs.render {} = ""
#guard SlotAttrs.render { name := "header" } = " name=\"header\""

/-- Typed attributes for `<source>`. Dual-purpose in the real spec --
inside `<picture>` it's `srcset`/`type`/`media` (no `src`); inside
`<video>`/`<audio>` it's `src`/`type` (no `srcset`) -- not distinguished
here, same documented-simplification spirit as the `ul`/`ol`/`table`
content-model notes in `Html/Tags.lean`'s module doc. -/
structure SourceAttrs where
  src : Option String := none
  srcset : Option String := none
  type : Option String := none
  media : Option String := none

def SourceAttrs.render (a : SourceAttrs) : String :=
  renderOpt "src" a.src ++ renderOpt "srcset" a.srcset ++ renderOpt "type" a.type ++
    renderOpt "media" a.media

#guard SourceAttrs.render {} = ""
#guard SourceAttrs.render { src := "a.mp4", type := "video/mp4" }
  = " src=\"a.mp4\" type=\"video/mp4\""

/-- Typed attributes for `<track>`. `src` is required -- a track without
one has nothing to load. -/
structure TrackAttrs where
  src : String
  kind : Option String := none
  srclang : Option String := none
  label : Option String := none
  default : Bool := false

def TrackAttrs.render (a : TrackAttrs) : String :=
  renderAttr "src" a.src ++ renderOpt "kind" a.kind ++ renderOpt "srclang" a.srclang ++
    renderOpt "label" a.label ++ renderBoolAttr "default" a.default

#guard TrackAttrs.render { src := "a.vtt" } = " src=\"a.vtt\""
#guard TrackAttrs.render { src := "a.vtt", kind := "subtitles", srclang := "en", default := true }
  = " src=\"a.vtt\" kind=\"subtitles\" srclang=\"en\" default"

/-- Typed attributes for `<iframe>`. `src` is required; `title` is
recommended for accessibility but stays optional (HTML validity doesn't
require it). -/
structure IframeAttrs where
  src : String
  title : Option String := none
  width : Option String := none
  height : Option String := none

def IframeAttrs.render (a : IframeAttrs) : String :=
  renderAttr "src" a.src ++ renderOpt "title" a.title ++ renderOpt "width" a.width ++
    renderOpt "height" a.height

#guard IframeAttrs.render { src := "/embed" } = " src=\"/embed\""
#guard IframeAttrs.render { src := "/embed", title := "t", width := "300", height := "150" }
  = " src=\"/embed\" title=\"t\" width=\"300\" height=\"150\""

/-- Typed attributes for `<embed>`. -/
structure EmbedAttrs where
  src : Option String := none
  type : Option String := none
  width : Option String := none
  height : Option String := none

def EmbedAttrs.render (a : EmbedAttrs) : String :=
  renderOpt "src" a.src ++ renderOpt "type" a.type ++ renderOpt "width" a.width ++
    renderOpt "height" a.height

#guard EmbedAttrs.render {} = ""
#guard EmbedAttrs.render { src := "a.swf", type := "application/x-shockwave-flash" }
  = " src=\"a.swf\" type=\"application/x-shockwave-flash\""

/-- Typed attributes for `<object>`. -/
structure ObjectAttrs where
  data : Option String := none
  type : Option String := none
  width : Option String := none
  height : Option String := none

def ObjectAttrs.render (a : ObjectAttrs) : String :=
  renderOpt "data" a.data ++ renderOpt "type" a.type ++ renderOpt "width" a.width ++
    renderOpt "height" a.height

#guard ObjectAttrs.render {} = ""
#guard ObjectAttrs.render { data := "a.pdf", type := "application/pdf" }
  = " data=\"a.pdf\" type=\"application/pdf\""

/-- Typed attributes for `<video>`. -/
structure VideoAttrs where
  src : Option String := none
  poster : Option String := none
  controls : Bool := false
  autoplay : Bool := false
  loop : Bool := false
  muted : Bool := false
  width : Option String := none
  height : Option String := none

def VideoAttrs.render (a : VideoAttrs) : String :=
  renderOpt "src" a.src ++ renderOpt "poster" a.poster ++ renderBoolAttr "controls" a.controls ++
    renderBoolAttr "autoplay" a.autoplay ++ renderBoolAttr "loop" a.loop ++
    renderBoolAttr "muted" a.muted ++ renderOpt "width" a.width ++ renderOpt "height" a.height

#guard VideoAttrs.render {} = ""
#guard VideoAttrs.render { src := "a.mp4", controls := true } = " src=\"a.mp4\" controls"

/-- Typed attributes for `<audio>`. -/
structure AudioAttrs where
  src : Option String := none
  controls : Bool := false
  autoplay : Bool := false
  loop : Bool := false
  muted : Bool := false

def AudioAttrs.render (a : AudioAttrs) : String :=
  renderOpt "src" a.src ++ renderBoolAttr "controls" a.controls ++
    renderBoolAttr "autoplay" a.autoplay ++ renderBoolAttr "loop" a.loop ++
    renderBoolAttr "muted" a.muted

#guard AudioAttrs.render {} = ""
#guard AudioAttrs.render { src := "a.mp3", controls := true } = " src=\"a.mp3\" controls"

/-- Typed attributes for `<map>`. `name` is required -- an image map
without one can't be referenced by an `<img usemap="#...">`. -/
structure MapAttrs where
  name : String

def MapAttrs.render (a : MapAttrs) : String :=
  renderAttr "name" a.name

#guard MapAttrs.render { name := "sitemap" } = " name=\"sitemap\""

/-- Typed attributes for `<area>`. `alt` is required whenever `href` is
present (real spec rule, not enforced here -- both stay independently
optional, same simplification level as everywhere else in this file). -/
structure AreaAttrs where
  href : Option String := none
  alt : Option String := none
  shape : Option String := none
  coords : Option String := none
  target : Option String := none

def AreaAttrs.render (a : AreaAttrs) : String :=
  renderOpt "href" a.href ++ renderOpt "alt" a.alt ++ renderOpt "shape" a.shape ++
    renderOpt "coords" a.coords ++ renderOpt "target" a.target

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

end Html
