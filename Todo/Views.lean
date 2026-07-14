import Html
import Htmx
import Todo.Db

/-!
`Html`/`Htmx`-built fragments for the todo app: the full page shell, the swappable
todo-list-plus-toggle-all region, a single item (view mode and edit mode), and the out-of-band
footer (count, filters, clear-completed). See `docs/todo-app-plan.md` for the overall design --
in particular, every mutating route (add/toggle/delete/edit-save/toggle-all/clear-completed)
shares `mutationFragment` below: it re-renders `#todo-list-section` as the primary swap target
plus `#todo-footer` as an out-of-band swap (`Htmx.Attrs.HtmxAttrs.hxSwapOob`), so one response
keeps the list and the footer's count/filters/clear-completed button in sync.
-/

namespace Todo

open Html

-- Only the tags below need `hx-*` attributes (the plain `Html.*` tags of the same name are used
-- everywhere else, matching `Main.lean`'s existing convention of qualifying `Htmx.button`
-- explicitly rather than `open Htmx`, which would otherwise clash with `Html`'s identically-named
-- tag functions).

/-- htmx, loaded the same way `Main.lean`'s original demo page loaded it. -/
def htmxScript : ScriptAttrs :=
  { src := "https://cdn.jsdelivr.net/npm/htmx.org@2.0.10/dist/htmx.min.js"
    integrity := "sha384-H5SrcfygHmAuTDZphMHqBJLc3FhssKjG7w/CeCpFReSfwBWDTKpkzPP8c+cLsK+V"
    crossorigin := "anonymous" }

/-- The official TodoMVC stylesheet, purely cosmetic -- the markup below uses its expected class
names (`todoapp`, `new-todo`, `todo-list`, `todo-count`, `filters`, `clear-completed`, ...) so the
demo reads as TodoMVC rather than unstyled HTML. -/
def todomvcCss : LinkAttrs :=
  { rel := "stylesheet", href := "https://unpkg.com/todomvc-app-css@2.4.3/index.css" }

/-- The URL path for a filter, and the filter a path (or a full URL ending in that path --
htmx's `HX-Current-URL` request header sends the whole current-page URL, not just its path, so
`endsWith` rather than exact equality is what lets `Main.lean`'s route handlers pass that header's
raw value straight in) denotes, defaulting to `.all` for anything that doesn't end in `/active` or
`/completed`. -/
def Filter.path : Filter → String
  | .all => "/"
  | .active => "/active"
  | .completed => "/completed"

def filterFromPath (path : String) : Filter :=
  if path.endsWith "/active" then .active
  else if path.endsWith "/completed" then .completed
  else .all

/-- One todo, view mode: a checkbox (`hx-post .../toggle`), a label that swaps itself into edit
mode on double-click (`hx-trigger="dblclick"`), and a delete button (`hx-delete`). All three post
back against `#todo-list-section` (see `listSection`) so the shared `mutationFragment` renderer
handles every one of them uniformly. -/
def itemView (item : Item) : Node .flow :=
  let itemId := s!"todo-{item.id}"
  li
    [ div
        [ Htmx.input
            { type := "checkbox", checked := item.completed }
            (hx := { hxPost := s!"/todos/{item.id}/toggle", hxTarget := "#todo-list-section",
                     hxSwap := some .outerHTML })
            (attrs := { class_ := "toggle" }),
          Htmx.label [item.title]
            (hx := { hxGet := s!"/todos/{item.id}/edit", hxTrigger := "dblclick",
                     hxTarget := s!"#{itemId}", hxSwap := some .outerHTML }),
          Htmx.button [] (hx := { hxDelete := s!"/todos/{item.id}", hxTarget := "#todo-list-section",
                                   hxSwap := some .outerHTML })
            (attrs := { class_ := "destroy" }) ]
        (attrs := { class_ := "view" }) ]
    (attrs := { id := itemId, class_ := if item.completed then "completed" else none })

/-- One todo, edit mode: swapped in by `itemView`'s label on double-click, targeting just this
`<li>` (not the whole list -- editing a title doesn't change the count or filters). Saving happens
on blur or Enter (`hx-trigger`), `hx-put`s the new title, and -- like every other mutation -- swaps
`#todo-list-section` and the out-of-band footer, since an edit can empty the title and delete the
todo (`Todo.setTitle`), which *does* change the count. -/
def itemEditView (item : Item) : Node .flow :=
  let itemId := s!"todo-{item.id}"
  li
    [ Htmx.input
        { type := "text", name := "title", value := item.title }
        (hx := { hxPut := s!"/todos/{item.id}", hxTrigger := "blur, keyup[key=='Enter']",
                 hxTarget := "#todo-list-section", hxSwap := some .outerHTML })
        (attrs := { class_ := "edit" })
        (rawAttrs := [("autofocus", "autofocus")]) ]
    (attrs := { id := itemId, class_ := "editing" })

/-- The swappable region containing the "mark all as complete" toggle and the list itself.
`id="todo-list-section"` is what every mutating handler's `hx-target`/`hx-swap="outerHTML"` names
-- see `mutationFragment`. -/
def listSection (items : Array Item) : Node .flow :=
  let allCompleted := items.size > 0 && items.all (·.completed)
  section_
    [ Htmx.input
        { type := "checkbox", checked := allCompleted }
        (hx := { hxPost := "/todos/toggle-all", hxTarget := "#todo-list-section",
                 hxSwap := some .outerHTML })
        (attrs := { id := "toggle-all", class_ := "toggle-all" }),
      label [] (attrs := {}) (rawAttrs := [("for", "toggle-all")]),
      ul (items.toList.map itemView) (attrs := { class_ := "todo-list" }) ]
    (attrs := { id := "todo-list-section", class_ := "main" })

/-- One `<li>` in the footer's filter list: a plain (non-htmx) link, so clicking a filter does a
normal full-page navigation to `/`, `/active`, or `/completed` -- simplest way to keep "which
filter" correctly reflected on the next htmx-driven mutation's `HX-Current-URL` header, with no
client-side state to keep in sync. -/
def filterLink (current target : Filter) (label : String) : Node .flow :=
  li [ a { href := target.path } [label]
         (attrs := { class_ := if current == target then "selected" else none }) ]

/-- The out-of-band footer: item count (correctly pluralized), the three filter links, and a
clear-completed button shown only when there's something to clear. Takes `allItems` -- every todo,
regardless of `filter` -- since the count and clear-completed button must reflect the whole list
even while viewing just the active or just the completed ones. `hxSwapOob := "true"` is what lets
every mutation's response update this alongside its primary `#todo-list-section` swap in one round
trip. -/
def footerFragment (allItems : Array Item) (filter : Filter) : Node .flow :=
  let activeCount := (allItems.filter (!·.completed)).size
  let completedCount := allItems.size - activeCount
  let countLabel := if activeCount == 1 then "1 item left" else s!"{activeCount} items left"
  Htmx.footer
    ([ p [countLabel] (attrs := { class_ := "todo-count" }),
       ul [ filterLink filter .all "All", filterLink filter .active "Active",
            filterLink filter .completed "Completed" ]
         (attrs := { class_ := "filters" }) ]
      ++ if completedCount > 0 then
           [ (Htmx.button ["Clear completed"]
               (hx := { hxDelete := "/todos/completed", hxTarget := "#todo-list-section",
                        hxSwap := some .outerHTML })
               (attrs := { class_ := "clear-completed" }) : Node .flow) ]
         else [])
    (hx := { hxSwapOob := "true" }) (attrs := { id := "todo-footer", class_ := "footer" })

/-- Shared by every mutating route: `listSection` (the primary `hx-target`/`hx-swap="outerHTML"`
swap) followed immediately by the out-of-band `footerFragment`, so one response keeps the list and
the footer's count/filters/clear-completed button in sync. `items` is the current filter's subset
(for the list itself); `allItems` is every todo (for the footer's count). -/
def mutationFragment (items allItems : Array Item) (filter : Filter) : String :=
  Node.render (listSection items) ++ Node.render (footerFragment allItems filter)

/-- The full page: header with the new-todo form (`hx-post /todos`, resetting itself after a
successful add since only `#todo-list-section` is swapped, not the form), the list section, and
the out-of-band-capable footer rendered inline (its `hx-swap-oob` attribute is simply ignored on a
normal full-page load, only mattering when it arrives as part of an htmx swap). `items` is the
current filter's subset (for the list itself); `allItems` is every todo (for the footer's count). -/
-- #guard smoke tests, matching the per-function convention in
-- Html/Tags.lean/Htmx/Tags.lean: minimal-input rendering for every function
-- above, a completed/selected-state variant where the function branches on
-- one, and the pluralization/conditional-button boundaries in
-- `footerFragment`. Strings below were captured from an actual `#eval` of
-- each expression against the live toolchain, not hand-derived.

private def sampleItem : Item := { id := 1, title := "Buy milk", completed := false }
private def sampleItemDone : Item := { id := 2, title := "Wash car", completed := true }
private def sampleItemUnsafe : Item := { id := 3, title := "<b>x</b> & \"y\"", completed := false }

#guard Node.render (itemView sampleItem) =
  "<li id=\"todo-1\"><div class=\"view\"><input type=\"checkbox\" class=\"toggle\" hx-post=\"/todos/1/toggle\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"><label hx-get=\"/todos/1/edit\" hx-trigger=\"dblclick\" hx-target=\"#todo-1\" hx-swap=\"outerHTML\">Buy milk</label><button class=\"destroy\" hx-delete=\"/todos/1\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"></button></div></li>"
#guard Node.render (itemView sampleItemDone) =
  "<li id=\"todo-2\" class=\"completed\"><div class=\"view\"><input type=\"checkbox\" checked class=\"toggle\" hx-post=\"/todos/2/toggle\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"><label hx-get=\"/todos/2/edit\" hx-trigger=\"dblclick\" hx-target=\"#todo-2\" hx-swap=\"outerHTML\">Wash car</label><button class=\"destroy\" hx-delete=\"/todos/2\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"></button></div></li>"
-- The title is escaped, same as any other user-supplied text (Html/Tags.lean's own `#guard`).
#guard Node.render (itemView sampleItemUnsafe) =
  "<li id=\"todo-3\"><div class=\"view\"><input type=\"checkbox\" class=\"toggle\" hx-post=\"/todos/3/toggle\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"><label hx-get=\"/todos/3/edit\" hx-trigger=\"dblclick\" hx-target=\"#todo-3\" hx-swap=\"outerHTML\">&lt;b&gt;x&lt;/b&gt; &amp; &quot;y&quot;</label><button class=\"destroy\" hx-delete=\"/todos/3\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"></button></div></li>"

#guard Node.render (itemEditView sampleItem) =
  "<li id=\"todo-1\" class=\"editing\"><input type=\"text\" name=\"title\" value=\"Buy milk\" class=\"edit\" hx-put=\"/todos/1\" hx-trigger=\"blur, keyup[key=='Enter']\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\" autofocus=\"autofocus\"></li>"
#guard Node.render (itemEditView sampleItemUnsafe) =
  "<li id=\"todo-3\" class=\"editing\"><input type=\"text\" name=\"title\" value=\"&lt;b&gt;x&lt;/b&gt; &amp; &quot;y&quot;\" class=\"edit\" hx-put=\"/todos/3\" hx-trigger=\"blur, keyup[key=='Enter']\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\" autofocus=\"autofocus\"></li>"

#guard Node.render (listSection #[]) =
  "<section id=\"todo-list-section\" class=\"main\"><input type=\"checkbox\" id=\"toggle-all\" class=\"toggle-all\" hx-post=\"/todos/toggle-all\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"><label for=\"toggle-all\"></label><ul class=\"todo-list\"></ul></section>"
#guard Node.render (listSection #[sampleItem]) =
  "<section id=\"todo-list-section\" class=\"main\"><input type=\"checkbox\" id=\"toggle-all\" class=\"toggle-all\" hx-post=\"/todos/toggle-all\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"><label for=\"toggle-all\"></label><ul class=\"todo-list\"><li id=\"todo-1\"><div class=\"view\"><input type=\"checkbox\" class=\"toggle\" hx-post=\"/todos/1/toggle\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"><label hx-get=\"/todos/1/edit\" hx-trigger=\"dblclick\" hx-target=\"#todo-1\" hx-swap=\"outerHTML\">Buy milk</label><button class=\"destroy\" hx-delete=\"/todos/1\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"></button></div></li></ul></section>"
-- `toggle-all`'s own `checked` requires a *nonempty* list where every item is completed --
-- a lone completed item flips it, an empty list (above) does not.
#guard Node.render (listSection #[sampleItemDone]) =
  "<section id=\"todo-list-section\" class=\"main\"><input type=\"checkbox\" checked id=\"toggle-all\" class=\"toggle-all\" hx-post=\"/todos/toggle-all\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"><label for=\"toggle-all\"></label><ul class=\"todo-list\"><li id=\"todo-2\" class=\"completed\"><div class=\"view\"><input type=\"checkbox\" checked class=\"toggle\" hx-post=\"/todos/2/toggle\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"><label hx-get=\"/todos/2/edit\" hx-trigger=\"dblclick\" hx-target=\"#todo-2\" hx-swap=\"outerHTML\">Wash car</label><button class=\"destroy\" hx-delete=\"/todos/2\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\"></button></div></li></ul></section>"

#guard Node.render (filterLink .all .all "All") = "<li><a href=\"/\" class=\"selected\">All</a></li>"
#guard Node.render (filterLink .all .active "Active") = "<li><a href=\"/active\">Active</a></li>"

-- Pluralization boundary (0/1/N) and the clear-completed button's presence
-- exactly tracking whether there's a completed item to clear.
#guard Node.render (footerFragment #[] .all) =
  "<footer id=\"todo-footer\" class=\"footer\" hx-swap-oob=\"true\"><p class=\"todo-count\">0 items left</p><ul class=\"filters\"><li><a href=\"/\" class=\"selected\">All</a></li><li><a href=\"/active\">Active</a></li><li><a href=\"/completed\">Completed</a></li></ul></footer>"
#guard Node.render (footerFragment #[sampleItem] .active) =
  "<footer id=\"todo-footer\" class=\"footer\" hx-swap-oob=\"true\"><p class=\"todo-count\">1 item left</p><ul class=\"filters\"><li><a href=\"/\">All</a></li><li><a href=\"/active\" class=\"selected\">Active</a></li><li><a href=\"/completed\">Completed</a></li></ul></footer>"
#guard Node.render (footerFragment #[sampleItem, sampleItemDone] .all) =
  "<footer id=\"todo-footer\" class=\"footer\" hx-swap-oob=\"true\"><p class=\"todo-count\">1 item left</p><ul class=\"filters\"><li><a href=\"/\" class=\"selected\">All</a></li><li><a href=\"/active\">Active</a></li><li><a href=\"/completed\">Completed</a></li></ul><button class=\"clear-completed\" hx-delete=\"/todos/completed\" hx-target=\"#todo-list-section\" hx-swap=\"outerHTML\">Clear completed</button></footer>"

-- `Filter.path`/`filterFromPath` round-trip for all three filters, plus
-- `filterFromPath`'s `endsWith`-on-a-full-URL behaviour (htmx's
-- `HX-Current-URL` sends a whole URL, not just a path) and its default to
-- `.all` for anything unrecognised.
#guard filterFromPath (Filter.path .all) == .all
#guard filterFromPath (Filter.path .active) == .active
#guard filterFromPath (Filter.path .completed) == .completed
#guard filterFromPath "http://localhost:2000/completed" == .completed
#guard filterFromPath "/garbage" == .all

def page (items allItems : Array Item) (filter : Filter) : String :=
  document (pretty := true) (lang := "en")
    [ head
        [ meta_ [("charset", "utf-8")], title "todos", script htmxScript, link todomvcCss ],
      body
        [ section_
            [ header
                [ h1 ["todos"],
                  Htmx.form
                    [ input
                        { name := "title", placeholder := "What needs to be done?" }
                        (attrs := { class_ := "new-todo" })
                        (rawAttrs := [("autofocus", "autofocus")]) ]
                    (hx := { hxPost := "/todos", hxTarget := "#todo-list-section",
                             hxSwap := some .outerHTML })
                    (rawAttrs := [("hx-on::after-request", "this.reset()")]) ]
                (attrs := { class_ := "header" }),
              listSection items,
              footerFragment allItems filter ]
            (attrs := { class_ := "todoapp" }),
          footer [p ["Double-click a todo to edit it."]] (attrs := { class_ := "info" }) ] ]

end Todo
