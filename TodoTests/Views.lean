import Html
import Todo.Views

/-!
Tests for `Todo.Views`.

`#guard` smoke tests, matching the per-function convention in `Html/Tags.lean`/`Htmx/Tags.lean`:
minimal-input rendering for every function there, a completed/selected-state variant where the
function branches on one, and the pluralization/conditional-button boundaries in
`footerFragment`. Strings below were captured from an actual `#eval` of each expression against
the live toolchain, not hand-derived.
-/

namespace TodoTests

open Todo Html

private def sampleItem : Item := { id := 1, title := "Buy milk", completed := false }
private def sampleItemDone : Item := { id := 2, title := "Wash car", completed := true }
private def sampleItemUnsafe : Item := { id := 3, title := "<b>x</b> & \"y\"", completed := false }

#guard Node.render (itemView urls sampleItem) =
  "<li id=\"todo-1\"><div class=\"view\"><input type=\"checkbox\" class=\"toggle\" hx-post=\"/todos/1/toggle\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"><label hx-get=\"/todos/1/edit\" hx-trigger=\"dblclick\" hx-target=\"#todo-1\" hx-swap=\"outerHTML\">Buy milk</label><button class=\"destroy\" hx-delete=\"/todos/1\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"></button></div></li>"
#guard Node.render (itemView urls sampleItemDone) =
  "<li id=\"todo-2\" class=\"completed\"><div class=\"view\"><input type=\"checkbox\" checked class=\"toggle\" hx-post=\"/todos/2/toggle\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"><label hx-get=\"/todos/2/edit\" hx-trigger=\"dblclick\" hx-target=\"#todo-2\" hx-swap=\"outerHTML\">Wash car</label><button class=\"destroy\" hx-delete=\"/todos/2\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"></button></div></li>"
-- The title is escaped, same as any other user-supplied text (Html/Tags.lean's own `#guard`).
#guard Node.render (itemView urls sampleItemUnsafe) =
  "<li id=\"todo-3\"><div class=\"view\"><input type=\"checkbox\" class=\"toggle\" hx-post=\"/todos/3/toggle\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"><label hx-get=\"/todos/3/edit\" hx-trigger=\"dblclick\" hx-target=\"#todo-3\" hx-swap=\"outerHTML\">&lt;b&gt;x&lt;/b&gt; &amp; &quot;y&quot;</label><button class=\"destroy\" hx-delete=\"/todos/3\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"></button></div></li>"

#guard Node.render (itemEditView urls sampleItem) =
  "<li id=\"todo-1\" class=\"editing\"><input type=\"text\" name=\"title\" value=\"Buy milk\" class=\"edit\" hx-put=\"/todos/1\" hx-trigger=\"blur, keyup[key=='Enter']\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\" autofocus=\"autofocus\"></li>"
#guard Node.render (itemEditView urls sampleItemUnsafe) =
  "<li id=\"todo-3\" class=\"editing\"><input type=\"text\" name=\"title\" value=\"&lt;b&gt;x&lt;/b&gt; &amp; &quot;y&quot;\" class=\"edit\" hx-put=\"/todos/3\" hx-trigger=\"blur, keyup[key=='Enter']\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\" autofocus=\"autofocus\"></li>"

#guard Node.render (listSection urls #[]) =
  "<section id=\"todo-list-section\" class=\"main\"><input type=\"checkbox\" id=\"toggle-all\" class=\"toggle-all\" hx-post=\"/todos/toggle-all\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"><label for=\"toggle-all\"></label><ul class=\"todo-list\"></ul></section>"
#guard Node.render (listSection urls #[sampleItem]) =
  "<section id=\"todo-list-section\" class=\"main\"><input type=\"checkbox\" id=\"toggle-all\" class=\"toggle-all\" hx-post=\"/todos/toggle-all\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"><label for=\"toggle-all\"></label><ul class=\"todo-list\"><li id=\"todo-1\"><div class=\"view\"><input type=\"checkbox\" class=\"toggle\" hx-post=\"/todos/1/toggle\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"><label hx-get=\"/todos/1/edit\" hx-trigger=\"dblclick\" hx-target=\"#todo-1\" hx-swap=\"outerHTML\">Buy milk</label><button class=\"destroy\" hx-delete=\"/todos/1\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"></button></div></li></ul></section>"
-- `toggle-all`'s own `checked` requires a *nonempty* list where every item is completed --
-- a lone completed item flips it, an empty list (above) does not.
#guard Node.render (listSection urls #[sampleItemDone]) =
  "<section id=\"todo-list-section\" class=\"main\"><input type=\"checkbox\" checked id=\"toggle-all\" class=\"toggle-all\" hx-post=\"/todos/toggle-all\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"><label for=\"toggle-all\"></label><ul class=\"todo-list\"><li id=\"todo-2\" class=\"completed\"><div class=\"view\"><input type=\"checkbox\" checked class=\"toggle\" hx-post=\"/todos/2/toggle\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"><label hx-get=\"/todos/2/edit\" hx-trigger=\"dblclick\" hx-target=\"#todo-2\" hx-swap=\"outerHTML\">Wash car</label><button class=\"destroy\" hx-delete=\"/todos/2\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"></button></div></li></ul></section>"

#guard Node.render (filterLink urls .all .all "All") = "<li><a href=\"/\" class=\"selected\">All</a></li>"
#guard Node.render (filterLink urls .all .active "Active") = "<li><a href=\"/active\">Active</a></li>"

-- Pluralization boundary (0/1/N) and the clear-completed button's presence
-- exactly tracking whether there's a completed item to clear.
#guard Node.render (footerFragment urls #[] .all) =
  "<footer id=\"todo-footer\" class=\"footer\" hx-swap-oob=\"true\"><span class=\"todo-count\">0 items left</span><ul class=\"filters\"><li><a href=\"/\" class=\"selected\">All</a></li><li><a href=\"/active\">Active</a></li><li><a href=\"/completed\">Completed</a></li></ul></footer>"
#guard Node.render (footerFragment urls #[sampleItem] .active) =
  "<footer id=\"todo-footer\" class=\"footer\" hx-swap-oob=\"true\"><span class=\"todo-count\">1 item left</span><ul class=\"filters\"><li><a href=\"/\">All</a></li><li><a href=\"/active\" class=\"selected\">Active</a></li><li><a href=\"/completed\">Completed</a></li></ul></footer>"
#guard Node.render (footerFragment urls #[sampleItem, sampleItemDone] .all) =
  "<footer id=\"todo-footer\" class=\"footer\" hx-swap-oob=\"true\"><span class=\"todo-count\">1 item left</span><ul class=\"filters\"><li><a href=\"/\" class=\"selected\">All</a></li><li><a href=\"/active\">Active</a></li><li><a href=\"/completed\">Completed</a></li></ul><button class=\"clear-completed\" hx-delete=\"/todos/completed\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\">Clear completed</button></footer>"

-- `Filter.path`/`filterFromPath` round-trip for all three filters, plus
-- `filterFromPath`'s `endsWith`-on-a-full-URL behaviour (htmx's
-- `HX-Current-URL` sends a whole URL, not just a path) and its default to
-- `.all` for anything unrecognised.
#guard filterFromPath (Filter.path .all urls) == .all
#guard filterFromPath (Filter.path .active urls) == .active
#guard filterFromPath (Filter.path .completed urls) == .completed
#guard filterFromPath "http://localhost:2000/completed" == .completed
#guard filterFromPath "/garbage" == .all

end TodoTests
