/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

import Html

namespace Htmx

/-- `hx-swap`'s value: rejects `hxSwap := some "banana"` at compile time.
See <https://htmx.org/attributes/hx-swap/>. -/
inductive HxSwap where
  | innerHTML
  | outerHTML
  | beforebegin
  | afterbegin
  | beforeend
  | afterend
  | delete
  | none

/-- Lets `{ hxGet := "/x" }` elaborate directly against `Option String` fields
without `some`. -/
scoped instance : Coe String (Option String) := ⟨some⟩

/-- Same rationale, for `hxBoost : Option Bool`. -/
scoped instance : Coe Bool (Option Bool) := ⟨some⟩

def HxSwap.render : HxSwap → String
  | .innerHTML => "innerHTML"
  | .outerHTML => "outerHTML"
  | .beforebegin => "beforebegin"
  | .afterbegin => "afterbegin"
  | .beforeend => "beforeend"
  | .afterend => "afterend"
  | .delete => "delete"
  | .none => "none"

/-- Typed htmx attributes for one element. `extends Html.HtmlAttrs`, same as
every `Html.*Attrs` record, so a single `attrs` argument carries both the
global HTML attributes and the `hx-*` ones; see the per-element records
below for the elements that also have their own `Html.*Attrs`. -/
structure HtmxAttrs extends Html.HtmlAttrs where
  hxGet : Option String := none
  hxPost : Option String := none
  hxPut : Option String := none
  hxPatch : Option String := none
  hxDelete : Option String := none
  hxTrigger : Option String := none
  hxTarget : Option String := none
  hxSwap : Option HxSwap := none
  hxSwapOob : Option String := none
  hxSelect : Option String := none
  hxSelectOob : Option String := none
  hxPushUrl : Option String := none
  hxConfirm : Option String := none
  hxIndicator : Option String := none
  hxVals : Option String := none
  hxBoost : Option Bool := none
  hxExt : Option String := none
  hxParams : Option String := none
  /-- `hx-on:<event>`: runs inline JS on a plain DOM event, e.g. `hxOn := [("click", "doThing()")]`.
  See <https://htmx.org/attributes/hx-on/>. -/
  hxOn : List (String × String) := []
  /-- `hx-on::<event>`: runs inline JS on an htmx-dispatched event, using htmx's kebab-case
  shorthand for its own event names, e.g. `hxOnHtmx := [("before-request", "doThing()")]`.
  See <https://htmx.org/attributes/hx-on/>. -/
  hxOnHtmx : List (String × String) := []

/-- One `(name, value)` pair if `v` is present, none otherwise. -/
private def optPair (name : String) : Option String → List (String × String)
  | none => []
  | some v => [(name, v)]

/-- `pairs` with `pre` prepended to each name. -/
private def prefixedPairs (pre : String) (pairs : List (String × String)) :
    List (String × String) :=
  pairs.map fun (name, value) => (pre ++ name, value)

/-- Flatten the `hx-*` fields to the `(name, value)` pairs `Html`'s `rawAttrs`
expects. The inherited `Html.HtmlAttrs` fields aren't included here; those
render through the normal `Html.*Attrs.render` path via each tag's
`toHtmlAttrs`/`to<Tag>Attrs` projection. -/
def HtmxAttrs.toPairs (a : HtmxAttrs) : List (String × String) :=
  optPair "hx-get" a.hxGet ++ optPair "hx-post" a.hxPost ++ optPair "hx-put" a.hxPut ++
    optPair "hx-patch" a.hxPatch ++ optPair "hx-delete" a.hxDelete ++
    optPair "hx-trigger" a.hxTrigger ++ optPair "hx-target" a.hxTarget ++
    (match a.hxSwap with | none => [] | some s => [("hx-swap", s.render)]) ++
    optPair "hx-swap-oob" a.hxSwapOob ++ optPair "hx-select" a.hxSelect ++
    optPair "hx-select-oob" a.hxSelectOob ++ optPair "hx-push-url" a.hxPushUrl ++
    optPair "hx-confirm" a.hxConfirm ++ optPair "hx-indicator" a.hxIndicator ++
    optPair "hx-vals" a.hxVals ++
    (match a.hxBoost with | none => [] | some b => [("hx-boost", if b then "true" else "false")]) ++
    optPair "hx-ext" a.hxExt ++ optPair "hx-params" a.hxParams ++
    prefixedPairs "hx-on:" a.hxOn ++ prefixedPairs "hx-on::" a.hxOnHtmx

/-! Per-element merged attrs, for the elements that have their own `Html.<Tag>Attrs`.
Each gives the matching `Htmx.<tag>` wrapper in `Htmx/Tags.lean` a single `attrs`
argument, exactly like the corresponding `Html.<tag>`. -/

structure OlAttrs extends Html.OlAttrs, HtmxAttrs
structure LiAttrs extends Html.LiAttrs, HtmxAttrs
structure BlockquoteAttrs extends Html.BlockquoteAttrs, HtmxAttrs
structure AAttrs extends Html.AAttrs, HtmxAttrs
structure FormAttrs extends Html.FormAttrs, HtmxAttrs
structure InputAttrs extends Html.InputAttrs, HtmxAttrs
structure LabelAttrs extends Html.LabelAttrs, HtmxAttrs
structure TextareaAttrs extends Html.TextareaAttrs, HtmxAttrs
structure OptionAttrs extends Html.OptionAttrs, HtmxAttrs
structure SelectAttrs extends Html.SelectAttrs, HtmxAttrs
structure ButtonAttrs extends Html.ButtonAttrs, HtmxAttrs
structure ImgAttrs extends Html.ImgAttrs, HtmxAttrs
structure ThAttrs extends Html.ThAttrs, HtmxAttrs
structure TdAttrs extends Html.TdAttrs, HtmxAttrs

end Htmx
