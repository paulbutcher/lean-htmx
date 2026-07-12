import Html.Node
import Html.Escape
import Html.Tags

/-!
Assembles a full HTML5 document (`Html.document`). Nothing earlier in the
plan produces a full page -- Phases 1-4 only build tags and the
`render : Node cat -> String` primitive; this is the missing top-level
piece that turns rendered content into a servable document. See
`docs/html-library-plan.md` Phase 5.
-/

namespace Html

/-- Assembles `<!DOCTYPE html>` plus the `<html>`/`<head>`/`<body>`
skeleton into one entry point. This is the only place `html`, `head`,
`body`, `meta`, `title`, `link` are used -- per Phase 0's category-lattice
decision, they are a special case of the document skeleton, not
general-purpose reusable tags (`Html/Tags.lean` deliberately doesn't
define them). Built entirely from `Node`'s public `element`/`voidElement`/
`textElement` (no access to `Node`'s private constructor needed), so
`body`'s content -- potentially large, unlike `head`'s -- is threaded
through `Node.element` rather than hand-concatenated, staying immune to
the quadratic-prepend trap documented in Phase 0/1.

Always emits `<meta charset="utf-8">` (a near-universal default); `meta`
supplies additional `name`/`content` pairs (e.g. `viewport`,
`description`), and `stylesheets` supplies `<link rel="stylesheet">`
`href`s.

`pretty` selects indented (`Node.renderPretty`) vs. compact (`Node.render`)
output -- Phase 6; `unit` is the string repeated per indentation level
(default two spaces) and is ignored when `pretty` is `false`. Pretty output
is for debugging/reading generated markup, not size-sensitive serving. -/
def document (title : String) (body : List (Node .flow))
    (metaTags : List (String × String) := []) (stylesheets : List String := [])
    (lang : Option String := none) (pretty : Bool := false) (unit : String := "  ") : String :=
  let charsetNode : Node .flow := Node.voidElement .flow "meta" (renderAttr "charset" "utf-8")
  let metaNodes : List (Node .flow) :=
    metaTags.map (fun (name, content) =>
      Node.voidElement .flow "meta" (renderAttr "name" name ++ renderAttr "content" content))
  let linkNodes : List (Node .flow) :=
    stylesheets.map (fun href =>
      Node.voidElement .flow "link" (renderAttr "rel" "stylesheet" ++ renderAttr "href" href))
  let titleNode : Node .flow := Node.textElement .flow "title" title
  let headNode : Node .flow :=
    Node.element .flow "head" ([charsetNode, titleNode] ++ metaNodes ++ linkNodes)
  let bodyNode : Node .flow := Node.element .flow "body" body
  let htmlAttrsStr := match lang with
    | some l => renderAttr "lang" l
    | none => ""
  let htmlNode : Node .flow := Node.element .flow "html" [headNode, bodyNode] htmlAttrsStr
  if pretty then "<!DOCTYPE html>\n" ++ Node.renderPretty htmlNode unit
  else "<!DOCTYPE html>" ++ Node.render htmlNode

#guard document "T" [] = "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>T</title></head><body></body></html>"
#guard document "T" [] (lang := some "en")
  = "<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>T</title></head><body></body></html>"
#guard document "T" [p [Node.text "hi"]]
  = "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>T</title></head><body><p>hi</p></body></html>"
#guard document "T" [] [("viewport", "width=device-width")]
  = "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>T</title>" ++
    "<meta name=\"viewport\" content=\"width=device-width\"></head><body></body></html>"
#guard document "T" [] [] ["/style.css"]
  = "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>T</title>" ++
    "<link rel=\"stylesheet\" href=\"/style.css\"></head><body></body></html>"
#guard document "<script>" [] = "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>&lt;script&gt;</title></head><body></body></html>"

#guard document "T" [] (pretty := true)
  = "<!DOCTYPE html>\n<html>\n  <head>\n    <meta charset=\"utf-8\">\n    <title>T</title>\n  </head>\n  <body></body>\n</html>"
#guard document "T" [p [Node.text "hi"]] (pretty := true)
  = "<!DOCTYPE html>\n<html>\n  <head>\n    <meta charset=\"utf-8\">\n    <title>T</title>\n  </head>\n  <body>\n    <p>hi</p>\n  </body>\n</html>"
#guard document "T" [] (pretty := true) (unit := "    ")
  = "<!DOCTYPE html>\n<html>\n    <head>\n        <meta charset=\"utf-8\">\n        <title>T</title>\n    </head>\n    <body></body>\n</html>"

end Html
