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

/-- Typed htmx attributes for one element. -/
structure HtmxAttrs where
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

/-- One `(name, value)` pair if `v` is present, none otherwise. -/
private def optPair (name : String) : Option String → List (String × String)
  | none => []
  | some v => [(name, v)]

/-- Flatten to the `(name, value)` pairs `Html`'s `rawAttrs` expects -/
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
    optPair "hx-ext" a.hxExt ++ optPair "hx-params" a.hxParams

end Htmx
