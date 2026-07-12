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

/-- A well-typed piece of rendered HTML, indexed by the content-model
category it's valid in. The constructor is private: the only way to build
a `Node` is through `element`/`voidElement` (and, later, the tag functions
built on them), which is what makes content-model correctness a corollary
of type soundness rather than something checked separately. -/
structure Node (cat : Category) where
  private mk ::
  private build : String → String

namespace Node

/-- `leaf s` appends `s` onto whatever has been built so far. Every
primitive here *appends* onto a left-to-right accumulator and never
prepends — prepending a small string onto already-large content is a
genuine O(n²) trap on this runtime (empirically confirmed via a throwaway
spike: a naive `open ++ children ++ close` per node, or a right-associated
"difference list" builder, are both quadratic in nesting depth; this
accumulator shape is linear even at millions of nodes). See
`docs/html-library-plan.md`, Phase 0. -/
private def leaf (s : String) : String → String := fun acc => acc ++ s

private def andThen (a b : String → String) : String → String := fun acc => b (a acc)

private def concatAll (bs : List (String → String)) : String → String :=
  bs.foldl andThen id

/-- Render a node to its final HTML string. The only place a `Node`'s
content is ever turned into a `String`. -/
def render (n : Node cat) : String := n.build ""

/-- A normal element: open tag, children (in order), close tag. -/
def element (cat : Category) (tag : String) (children : List (Node cat)) : Node cat :=
  ⟨andThen (andThen (leaf s!"<{tag}>") (concatAll (children.map (·.build)))) (leaf s!"</{tag}>")⟩

/-- A void element: self-closing, takes no children, has no closing tag
(`<br>`, `<img>`, `<input>`, ...). -/
def voidElement (cat : Category) (tag : String) : Node cat :=
  ⟨leaf s!"<{tag}>"⟩

end Node

/-- Phrasing content is always valid wherever flow content is valid. -/
instance : Coe (Node .phrasing) (Node .flow) where
  coe n := ⟨n.build⟩

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

end Html
