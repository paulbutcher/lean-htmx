import Html.Node
import Html.Escape
import Html.Attrs
import Html.Tags

/-!
Assembles a full HTML5 document (`Html.document`). Nothing earlier in the
plan produces a full page -- Phases 1-4 only build tags and the
`render : Node cat -> String` primitive; this is the missing top-level
piece that turns rendered content into a servable document. See
`docs/html-library-plan.md` Phase 5.
-/

namespace Html

/-- Prepends `<!DOCTYPE html>` and wraps `children` in a single `<html>`
element -- the only tag `document` builds itself. `head`, `body`, `title`,
`meta`, `link`, `script` are ordinary tags (`Html/Tags.lean`); callers
build those themselves and pass the results in as `children` (typically
`[head [...], body [...]]`) -- `document` doesn't inject a charset `meta`,
a `title`, or anything else on their behalf.

`pretty` selects indented (`Node.renderPretty`) vs. compact (`Node.render`)
output -- Phase 6; `unit` is the string repeated per indentation level
(default two spaces) and is ignored when `pretty` is `false`. Pretty output
is for debugging/reading generated markup, not size-sensitive serving. -/
def document (children : List (Node .flow))
    (lang : Option String := none) (pretty : Bool := false) (unit : String := "  ") : String :=
  let attrsStr := match lang with
    | some l => renderAttr "lang" l
    | none => ""
  let htmlNode : Node .flow := Node.element .flow "html" children attrsStr
  if pretty then "<!DOCTYPE html>\n" ++ Node.renderPretty htmlNode unit
  else "<!DOCTYPE html>" ++ Node.render htmlNode

end Html
