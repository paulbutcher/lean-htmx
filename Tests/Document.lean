import Html.Document
import Html.Node
import Html.Tags

/-!
Tests for `Html.Document`.
-/

namespace Tests

open Html

#guard document [head [], body []]
  = "<!DOCTYPE html><html><head></head><body></body></html>"
#guard document [head [], body []] (lang := "en")
  = "<!DOCTYPE html><html lang=\"en\"><head></head><body></body></html>"
#guard document [head [], body [p [Node.text "hi"]]]
  = "<!DOCTYPE html><html><head></head><body><p>hi</p></body></html>"
#guard document [head [title "T"], body []]
  = "<!DOCTYPE html><html><head><title>T</title></head><body></body></html>"
#guard document [head [meta_ [("charset", "utf-8")], title "T"], body []]
  = "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>T</title></head><body></body></html>"
#guard document [head [title "T", meta_ [("name", "viewport"), ("content", "width=device-width")]], body []]
  = "<!DOCTYPE html><html><head><title>T</title>" ++
    "<meta name=\"viewport\" content=\"width=device-width\"></head><body></body></html>"
#guard document [head [title "T", link { rel := "stylesheet", href := "/style.css" }], body []]
  = "<!DOCTYPE html><html><head><title>T</title>" ++
    "<link rel=\"stylesheet\" href=\"/style.css\"></head><body></body></html>"
#guard document [head [title "<script>"], body []]
  = "<!DOCTYPE html><html><head><title>&lt;script&gt;</title></head><body></body></html>"
#guard document [head [title "T", script { src := "/a.js" }], body []]
  = "<!DOCTYPE html><html><head><title>T</title>" ++
    "<script src=\"/a.js\"></script></head><body></body></html>"
#guard document
    [head [title "T", script { src := "/a.js", integrity := "sha384-x", crossorigin := "anonymous" }],
     body []]
  = "<!DOCTYPE html><html><head><title>T</title>" ++
    "<script src=\"/a.js\" integrity=\"sha384-x\" crossorigin=\"anonymous\"></script></head><body></body></html>"

#guard document [head [], body []] (pretty := true)
  = "<!DOCTYPE html>\n<html>\n  <head></head>\n  <body></body>\n</html>"
#guard document [head [title "T"], body [p [Node.text "hi"]]] (pretty := true)
  = "<!DOCTYPE html>\n<html>\n  <head>\n    <title>T</title>\n  </head>\n  <body>\n    <p>hi</p>\n  </body>\n</html>"
#guard document [head [], body []] (pretty := true) (unit := "    ")
  = "<!DOCTYPE html>\n<html>\n    <head></head>\n    <body></body>\n</html>"

end Tests
