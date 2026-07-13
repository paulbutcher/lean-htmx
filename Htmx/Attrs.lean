/-!
Typed htmx attribute vocabulary. See `docs/html-library-plan.md` 1.4 and
Phase 6 for the design rationale: this is a *separate* library from `Html`,
built entirely on `Html`'s public API (`rawAttrs`), so `Html` needed zero
changes to support it. The accepted tradeoff (also 1.4): this buys full
type safety for the *shape* of individual htmx attributes (e.g. `hxSwap`
can't be `"banana"`), but not a whole-page "this document does/doesn't use
htmx" guarantee -- an `Htmx.div` is type-indistinguishable from `Html.div`
once built.
-/

namespace Htmx

/-- `hx-swap`'s value, closed per 1.4's example: a real enum that rejects
`hxSwap := some "banana"` at compile time, unlike a bare `String` field
would. See <https://htmx.org/attributes/hx-swap/>. -/
inductive HxSwap where
  | innerHTML
  | outerHTML
  | beforebegin
  | afterbegin
  | beforeend
  | afterend
  | delete
  | none

def HxSwap.render : HxSwap → String
  | .innerHTML => "innerHTML"
  | .outerHTML => "outerHTML"
  | .beforebegin => "beforebegin"
  | .afterbegin => "afterbegin"
  | .beforeend => "beforeend"
  | .afterend => "afterend"
  | .delete => "delete"
  | .none => "none"

/-- Typed htmx attributes for one element. Every field is optional and
additive, mirroring `Html`'s own `HtmlAttrs`/per-element records (structure
of `Option _ := none` fields) -- see `Htmx/Tags.lean` for how a value of
this type is threaded into a tag call. Request-triggering attributes
(`hxGet`/.../`hxDelete`) and most others stay plain `String` for v1, same
non-goal as `Html`'s `href`/`src` (1.3): this models htmx's attribute
*shape*, not URL or trigger-spec grammar. `hxSwap` is the one field with a
genuinely closed vocabulary worth modeling as an enum (see `HxSwap`);
`hxBoost` is `Bool` because htmx only accepts literal `true`/`false` there,
unlike `hxPushUrl` (also `true`/`false`, but *or* a URL, so it stays
`String`). -/
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

/-- Flatten to the `(name, value)` pairs `Html`'s `rawAttrs` expects --
values here are the *raw*, unescaped strings; escaping happens once, at
render time, in `Html.renderRawAttrs`, exactly like every other `rawAttrs`
caller. This is the "validate `hx`, flatten it to `List (String × String)`"
step 1.4 describes; `Htmx/Tags.lean`'s wrapper tags do the forwarding. -/
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

-- #guard tests, one (or more) per field.
#guard HtmxAttrs.toPairs {} = []
#guard HtmxAttrs.toPairs { hxGet := some "/x" } = [("hx-get", "/x")]
#guard HtmxAttrs.toPairs { hxPost := some "/x" } = [("hx-post", "/x")]
#guard HtmxAttrs.toPairs { hxPut := some "/x" } = [("hx-put", "/x")]
#guard HtmxAttrs.toPairs { hxPatch := some "/x" } = [("hx-patch", "/x")]
#guard HtmxAttrs.toPairs { hxDelete := some "/x" } = [("hx-delete", "/x")]
#guard HtmxAttrs.toPairs { hxTrigger := some "click" } = [("hx-trigger", "click")]
#guard HtmxAttrs.toPairs { hxTarget := some "#result" } = [("hx-target", "#result")]
#guard HtmxAttrs.toPairs { hxSwap := some .outerHTML } = [("hx-swap", "outerHTML")]
#guard HtmxAttrs.toPairs { hxSwap := some .none } = [("hx-swap", "none")]
#guard HtmxAttrs.toPairs { hxSwapOob := some "true" } = [("hx-swap-oob", "true")]
#guard HtmxAttrs.toPairs { hxSelect := some "#x" } = [("hx-select", "#x")]
#guard HtmxAttrs.toPairs { hxSelectOob := some "#x" } = [("hx-select-oob", "#x")]
#guard HtmxAttrs.toPairs { hxPushUrl := some "true" } = [("hx-push-url", "true")]
#guard HtmxAttrs.toPairs { hxConfirm := some "Sure?" } = [("hx-confirm", "Sure?")]
#guard HtmxAttrs.toPairs { hxIndicator := some "#spinner" } = [("hx-indicator", "#spinner")]
#guard HtmxAttrs.toPairs { hxVals := some "{\"x\":1}" } = [("hx-vals", "{\"x\":1}")]
#guard HtmxAttrs.toPairs { hxBoost := some true } = [("hx-boost", "true")]
#guard HtmxAttrs.toPairs { hxBoost := some false } = [("hx-boost", "false")]  -- explicit, not omitted
#guard HtmxAttrs.toPairs { hxExt := some "json-enc" } = [("hx-ext", "json-enc")]
#guard HtmxAttrs.toPairs { hxParams := some "*" } = [("hx-params", "*")]

#guard HtmxAttrs.toPairs { hxGet := some "/x", hxTarget := some "#y", hxSwap := some .innerHTML }
  = [("hx-get", "/x"), ("hx-target", "#y"), ("hx-swap", "innerHTML")]

end Htmx
