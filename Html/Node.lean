import Html.Escape

/-!
Core node representation and content-model machinery for the typed HTML
library. See `docs/html-library-plan.md` for the design rationale.
-/

namespace Html

/-- HTML content-model category. Only `flow` and `phrasing` are modeled in
v1 (see `docs/html-library-plan.md` 1.1, Phase 0) — phrasing content is a
subset of flow content (`Coe` below), which is what lets a phrasing tag
like `span` appear directly among a flow element's children. -/
inductive Category where
  | flow
  | phrasing

/-- Internal tree representation. A `Node` used to be *only* an append-only
`String → String` accumulator (see git history / Phase 0's spike) — fast,
but it threw away tree shape the moment a node was built, which is exactly
the information a pretty-printer (Phase 6) needs to know where to put
newlines and how deep to indent. Keeping a tree instead doesn't reintroduce
the Phase 0 quadratic trap: that trap was specifically about *prepending* a
small string onto an already-large one (`open ++ children ++ close`, or a
right-associated difference-list). A tree rendered by a single left-to-right
accumulator-threading walk (below) still only ever *appends* a small piece
onto a growing accumulator, which is the empirically-linear shape Phase 0
settled on — this is the same algorithm, just data first and function
second, so it stays linear.

`elem`'s `block` field records the pretty-printer's layout decision for its
*children*, fixed at construction time by `elementOf`/`element`'s
`contentCat`: `true` (children are `flow`) lays each child out on its own
indented line, `false` (children are `phrasing`) concatenates them inline
with no added whitespace. This isn't cosmetic — inserting whitespace
between phrasing/text runs is visible in rendered output (e.g.
`<span>a</span><span>b</span>` vs `<span>a</span> <span>b</span>`), so
phrasing content must never get pretty-printer-added newlines. Void
elements and raw-text elements (`textarea`, `option`, `pre`'s escaped
content is fine since it's phrasing) never get whitespace injected *into*
them either way — see `renderPrettyInto` below. -/
private inductive Repr where
  | leaf (s : String)
  | void (tag : String) (attrsStr : String)
  | rawText (tag : String) (attrsStr : String) (content : String)
  | elem (tag : String) (attrsStr : String) (children : List Repr) (block : Bool)

/-- A well-typed piece of rendered HTML, indexed by the content-model
category it's valid in. The constructor is private: the only way to build
a `Node` is through `element`/`elementOf`/`voidElement`/`textElement`/
`text`/`unsafeRaw` (and, on top of those, the tag functions in
`Html/Tags.lean`), which is what makes content-model correctness a
corollary of type soundness rather than something checked separately. -/
structure Node (cat : Category) where
  private mk ::
  private repr : Repr

namespace Node

/-- Compact rendering: a left-to-right accumulator-threading walk that only
ever appends a small piece onto `acc` — never prepends — which is the shape
Phase 0's spike found to be linear even at millions of nodes (see `Repr`'s
doc comment). -/
private def renderCompactInto : Repr → String → String
  | .leaf s, acc => acc ++ s
  | .void tag attrsStr, acc => acc ++ s!"<{tag}{attrsStr}>"
  | .rawText tag attrsStr content, acc => acc ++ s!"<{tag}{attrsStr}>{content}</{tag}>"
  | .elem tag attrsStr children _, acc =>
    let acc := acc ++ s!"<{tag}{attrsStr}>"
    let acc := children.foldl (fun acc c => renderCompactInto c acc) acc
    acc ++ s!"</{tag}>"

/-- Render a node to its final, compact (no added whitespace) HTML string.
The only place a `Node`'s content is ever turned into a compact `String`. -/
def render (n : Node cat) : String := renderCompactInto n.repr ""

/-- Rebuilds the indentation string from scratch at every call, so a chain
of `D` nested block elements does `O(D)` work at each of `D` levels —
`O(D²)` total. Unlike `renderCompactInto`/`renderPrettyInto`'s inline
branch, this is *not* the Phase 0 prepend trap creeping back in: it's the
minimum possible cost, because the pretty-printed *output itself* is
`O(D²)` characters for such a chain (line `d` carries `O(d)` leading
spaces, summed `1..D`). No accumulator discipline can render an `O(D²)`
string in less than `O(D²)` time. -/
private def indent (depth : Nat) (unit : String) : String :=
  String.join (List.replicate depth unit)

/-- Pretty (indented) rendering, `depth` levels deep, `unit` spaces/tabs per
level. Same append-only accumulator shape as `renderCompactInto` (see
`Repr`'s doc comment for why this stays linear), plus layout decisions:
- A `block := false` element (`elem`'s children are `phrasing`) renders
  exactly like `renderCompactInto` — no newlines or indentation added
  anywhere inside it, at any depth, since whitespace is significant between
  text/inline content.
- A `block := true` element with no children, or exactly one `leaf` child,
  also stays on one line (`<li>one</li>`, `<div></div>`) — not worth
  exploding.
- Otherwise each child is placed on its own line at `depth + 1`.
- `void`/`rawText` nodes are always emitted verbatim, never recursed into —
  this is what keeps `<textarea>`/`<option>` content (and any other
  raw-text element added later) whitespace-exact regardless of surrounding
  layout. -/
private def renderPrettyInto (unit : String) (r : Repr) (depth : Nat) (acc : String) : String :=
  match r with
  | .leaf s => acc ++ s
  | .void tag attrsStr => acc ++ s!"<{tag}{attrsStr}>"
  | .rawText tag attrsStr content => acc ++ s!"<{tag}{attrsStr}>{content}</{tag}>"
  | .elem tag attrsStr children false =>
    -- Inline layout (phrasing children): identical to compact rendering.
    let acc := acc ++ s!"<{tag}{attrsStr}>"
    let acc := children.foldl (fun acc c => renderPrettyInto unit c depth acc) acc
    acc ++ s!"</{tag}>"
  | .elem tag attrsStr [] true =>
    acc ++ s!"<{tag}{attrsStr}></{tag}>"
  | .elem tag attrsStr [.leaf s] true =>
    -- A lone text child isn't worth exploding onto its own line.
    acc ++ s!"<{tag}{attrsStr}>{s}</{tag}>"
  | .elem tag attrsStr [c] true =>
    let acc := acc ++ s!"<{tag}{attrsStr}>\n" ++ indent (depth + 1) unit
    let acc := renderPrettyInto unit c (depth + 1) acc
    acc ++ "\n" ++ indent depth unit ++ s!"</{tag}>"
  | .elem tag attrsStr (c :: cs) true =>
    -- Block layout (flow children), more than one: one child per line.
    let acc := acc ++ s!"<{tag}{attrsStr}>\n" ++ indent (depth + 1) unit
    let acc := renderPrettyInto unit c (depth + 1) acc
    let acc := cs.foldl (fun acc c =>
      renderPrettyInto unit c (depth + 1) (acc ++ "\n" ++ indent (depth + 1) unit)) acc
    acc ++ "\n" ++ indent depth unit ++ s!"</{tag}>"
termination_by sizeOf r

/-- Render a node as indented, human-readable HTML — see `renderPrettyInto`
for the layout rules (block `flow` children one per line, inline `phrasing`
children with no added whitespace, raw-text elements always verbatim).
`unit` is the string repeated per indentation level (default two spaces). -/
def renderPretty (n : Node cat) (unit : String := "  ") : String :=
  renderPrettyInto unit n.repr 0 ""

/-- A normal element whose children may be a *different*, narrower
category than the element itself -- e.g. `p` is flow content but only
accepts phrasing children (HTML5 disallows a `<div>` directly inside a
`<p>`), which this makes a type error rather than a spec violation caught
only at runtime. `attrsStr` is the pre-rendered, already-escaped attribute
string (e.g. from `HtmlAttrs.render` + `renderRawAttrs`, built by the tag
functions in `Html/Tags.lean`), spliced directly after the tag name. -/
def elementOf (cat contentCat : Category) (tag : String)
    (children : List (Node contentCat)) (attrsStr : String := "") : Node cat :=
  ⟨.elem tag attrsStr (children.map (·.repr)) (contentCat matches .flow)⟩

/-- A normal element whose children are the *same* category as the
element itself (e.g. `div`: a flow element containing flow content). The
common case of `elementOf`. -/
def element (cat : Category) (tag : String) (children : List (Node cat))
    (attrsStr : String := "") : Node cat :=
  elementOf cat cat tag children attrsStr

/-- A void element: self-closing, takes no children, has no closing tag
(`<br>`, `<img>`, `<input>`, ...). -/
def voidElement (cat : Category) (tag : String) (attrsStr : String := "") : Node cat :=
  ⟨.void tag attrsStr⟩

/-- An element whose content model is plain text, not nested elements
(`<textarea>`, `<option>` -- these are RCDATA-like in HTML5: entities are
still escaped normally, but `<`/`>` in the content are never parsed as
nested markup, so typing their content as `List (Node cat)` would be
misleading). Pretty-printing never touches `content` -- see `Repr`'s doc
comment. -/
def textElement (cat : Category) (tag : String) (content : String)
    (attrsStr : String := "") : Node cat :=
  ⟨.rawText tag attrsStr (escape content)⟩

/-- A leaf of escaped text content, valid in any category (plain text is
both flow and phrasing content). -/
def text (s : String) : Node cat := ⟨.leaf (escape s)⟩

/-- String literals can stand directly for a `text` leaf wherever a `Node`
is expected (e.g. among a tag's children), so callers write `"hi"` instead
of `Node.text "hi"`. -/
instance : Coe String (Node cat) where
  coe := text

/-- Verbatim, unescaped markup, trusted as-is, usable as content of any
category. Named loudly, not `raw` -- misuse with untrusted input is a real
XSS hole; see `docs/html-library-plan.md` 1.3. Explicitly out of scope for
any correctness proof in this library. -/
def unsafeRaw (s : String) : Node cat := ⟨.leaf s⟩

end Node

/-- Phrasing content is always valid wherever flow content is valid. -/
instance : Coe (Node .phrasing) (Node .flow) where
  coe n := ⟨n.repr⟩

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

end Html
