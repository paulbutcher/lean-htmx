import Html
import Htmx
import Todo.Db
import Todo.Urls

/-!
`Html`/`Htmx`-built fragments for the todo app: the full page shell, the swappable
todo-list-plus-toggle-all region, a single item (view mode and edit mode), and the out-of-band
footer (count, filters, clear-completed). See `docs/todo-app-plan.md` for the overall design --
in particular, every mutating route (add/toggle/delete/edit-save/toggle-all/clear-completed)
shares `mutationFragment` below: it re-renders `#todo-list-section` as the primary swap target
plus `#todo-footer` as an out-of-band swap (`Htmx.Attrs.HtmxAttrs.hxSwapOob`), so one response
keeps the list and the footer's count/filters/clear-completed button in sync.

Every function below is generic over `{Urls} [HasUrls Urls]` (`Todo/Urls.lean`) rather than a
concrete URL-bundle type: `Main.lean`'s `application` macro generates that concrete struct, and
`Todo` (this file included) sits upstream of `Main` in the import graph, so it can't name that
struct directly (`docs/application-macro-plan.md`'s Phase 3 notes).
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
def Filter.path {Urls : Type} [HasUrls Urls] (urls : Urls) : Filter → String
  | .all => HasUrls.index urls
  | .active => HasUrls.active urls
  | .completed => HasUrls.completed urls

def filterFromPath (path : String) : Filter :=
  if path.endsWith "/active" then .active
  else if path.endsWith "/completed" then .completed
  else .all

/-- One todo, view mode: a checkbox (`hx-post .../toggle`), a label that swaps itself into edit
mode on double-click (`hx-trigger="dblclick"`), and a delete button (`hx-delete`). All three post
back against `#todo-list-section` (see `listSection`) so the shared `mutationFragment` renderer
handles every one of them uniformly. -/
def itemView {Urls : Type} [HasUrls Urls] (urls : Urls) (item : Item) : Node .flow :=
  let itemId := s!"todo-{item.id}"
  li
    [ div
        [ Htmx.input
            { type := "checkbox", checked := item.completed }
            (hx := { hxPost := HasUrls.todoToggle urls item.id.toNatClampNeg,
                     hxTarget := "#todo-list-section", hxSwap := some .outerHTML })
            (attrs := { class_ := "toggle" }),
          Htmx.label [item.title]
            (hx := { hxGet := HasUrls.todoEdit urls item.id.toNatClampNeg, hxTrigger := "dblclick",
                     hxTarget := s!"#{itemId}", hxSwap := some .outerHTML }),
          Htmx.button [] (hx := { hxDelete := HasUrls.todo urls item.id.toNatClampNeg,
                                   hxTarget := "#todo-list-section", hxSwap := some .outerHTML })
            (attrs := { class_ := "destroy" }) ]
        (attrs := { class_ := "view" }) ]
    (attrs := { id := itemId, class_ := if item.completed then "completed" else none })

/-- One todo, edit mode: swapped in by `itemView`'s label on double-click, targeting just this
`<li>` (not the whole list -- editing a title doesn't change the count or filters). Saving happens
on blur or Enter (`hx-trigger`), `hx-put`s the new title, and -- like every other mutation -- swaps
`#todo-list-section` and the out-of-band footer, since an edit can empty the title and delete the
todo (`Todo.setTitle`), which *does* change the count. -/
def itemEditView {Urls : Type} [HasUrls Urls] (urls : Urls) (item : Item) : Node .flow :=
  let itemId := s!"todo-{item.id}"
  li
    [ Htmx.input
        { type := "text", name := "title", value := item.title }
        (hx := { hxPut := HasUrls.todo urls item.id.toNatClampNeg,
                 hxTrigger := "blur, keyup[key=='Enter']",
                 hxTarget := "#todo-list-section", hxSwap := some .outerHTML })
        (attrs := { class_ := "edit" })
        (rawAttrs := [("autofocus", "autofocus")]) ]
    (attrs := { id := itemId, class_ := "editing" })

/-- The swappable region containing the "mark all as complete" toggle and the list itself.
`id="todo-list-section"` is what every mutating handler's `hx-target`/`hx-swap="outerHTML"` names
-- see `mutationFragment`. -/
def listSection {Urls : Type} [HasUrls Urls] (urls : Urls) (items : Array Item) : Node .flow :=
  let allCompleted := items.size > 0 && items.all (·.completed)
  section_
    [ Htmx.input
        { type := "checkbox", checked := allCompleted }
        (hx := { hxPost := HasUrls.toggleAll urls, hxTarget := "#todo-list-section",
                 hxSwap := some .outerHTML })
        (attrs := { id := "toggle-all", class_ := "toggle-all" }),
      label [] (attrs := {}) (rawAttrs := [("for", "toggle-all")]),
      ul (items.toList.map (itemView urls)) (attrs := { class_ := "todo-list" }) ]
    (attrs := { id := "todo-list-section", class_ := "main" })

/-- One `<li>` in the footer's filter list: a plain (non-htmx) link, so clicking a filter does a
normal full-page navigation to `/`, `/active`, or `/completed` -- simplest way to keep "which
filter" correctly reflected on the next htmx-driven mutation's `HX-Current-URL` header, with no
client-side state to keep in sync. -/
def filterLink {Urls : Type} [HasUrls Urls] (urls : Urls) (current target : Filter)
    (label : String) : Node .flow :=
  li [ a { href := Filter.path urls target } [label]
         (attrs := { class_ := if current == target then "selected" else none }) ]

/-- The out-of-band footer: item count (correctly pluralized), the three filter links, and a
clear-completed button shown only when there's something to clear. Takes `allItems` -- every todo,
regardless of `filter` -- since the count and clear-completed button must reflect the whole list
even while viewing just the active or just the completed ones. `hxSwapOob := "true"` is what lets
every mutation's response update this alongside its primary `#todo-list-section` swap in one round
trip. The count is a bare `<span>`, matching what the TodoMVC stylesheet expects it to be -- no
margin override needed, since `<span>` (unlike `<p>`) has no browser default margin to cancel. -/
def footerFragment {Urls : Type} [HasUrls Urls] (urls : Urls) (allItems : Array Item)
    (filter : Filter) : Node .flow :=
  let activeCount := (allItems.filter (!·.completed)).size
  let completedCount := allItems.size - activeCount
  let countLabel := if activeCount == 1 then "1 item left" else s!"{activeCount} items left"
  Htmx.footer
    ([ (span [countLabel] (attrs := { class_ := "todo-count" }) : Node .flow),
       ul [ filterLink urls filter .all "All", filterLink urls filter .active "Active",
            filterLink urls filter .completed "Completed" ]
         (attrs := { class_ := "filters" }) ]
      ++ if completedCount > 0 then
           [ (Htmx.button ["Clear completed"]
               (hx := { hxDelete := HasUrls.clearCompleted urls, hxTarget := "#todo-list-section",
                        hxSwap := some .outerHTML })
               (attrs := { class_ := "clear-completed" }) : Node .flow) ]
         else [])
    (hx := { hxSwapOob := "true" }) (attrs := { id := "todo-footer", class_ := "footer" })

/-- Shared by every mutating route: `listSection` (the primary `hx-target`/`hx-swap="outerHTML"`
swap) followed immediately by the out-of-band `footerFragment`, so one response keeps the list and
the footer's count/filters/clear-completed button in sync. `items` is the current filter's subset
(for the list itself); `allItems` is every todo (for the footer's count). -/
def mutationFragment {Urls : Type} [HasUrls Urls] (urls : Urls) (items allItems : Array Item)
    (filter : Filter) : String :=
  Node.render (listSection urls items) ++ Node.render (footerFragment urls allItems filter)

/-- The full page: header with the new-todo form (`hx-post /todos`, resetting itself after a
successful add since only `#todo-list-section` is swapped, not the form), the list section, and
the out-of-band-capable footer rendered inline (its `hx-swap-oob` attribute is simply ignored on a
normal full-page load, only mattering when it arrives as part of an htmx swap). `items` is the
current filter's subset (for the list itself); `allItems` is every todo (for the footer's count). -/
def page {Urls : Type} [HasUrls Urls] (urls : Urls) (items allItems : Array Item)
    (filter : Filter) : String :=
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
                    (hx := { hxPost := HasUrls.todos urls, hxTarget := "#todo-list-section",
                             hxSwap := some .outerHTML })
                    (rawAttrs := [("hx-on::after-request", "this.reset()")]) ]
                (attrs := { class_ := "header" }),
              listSection urls items,
              footerFragment urls allItems filter ]
            (attrs := { class_ := "todoapp" }),
          footer [p ["Double-click a todo to edit it."]] (attrs := { class_ := "info" }) ] ]

end Todo
