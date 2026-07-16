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

/-- Same rationale as `Html.instCoeStringOptionString` (`Html/Attrs.lean`):
lets `{ hxGet := "/x" }` elaborate directly against `Option String` fields
without `some`. Scoped to `Htmx`, and safe for the same reason -- no shared
unresolved metavariable between `String` and `Option String` for coercion
insertion to choke on (see `docs/html-library-plan.md`'s discussion of this
vs. the unrelated 1.2 friction). -/
scoped instance : Coe String (Option String) := ⟨some⟩

/-- Same rationale, for `hxBoost : Option Bool`. -/
scoped instance : Coe Bool (Option Bool) := ⟨some⟩

-- Deliberately **no** `Coe HxSwap (Option HxSwap)`: spiked and rejected.
-- Leading-dot notation (`hxSwap := .outerHTML`) resolves its identifier
-- against the *expected* type's namespace directly (here `Option`) and
-- never falls back to a coercion source's namespace, so the coercion
-- wouldn't even fire for the common case -- confirmed empirically, `.
-- outerHTML` fails with "Unknown constant `Option.outerHTML`". Worse, since
-- `HxSwap` happens to have its own `none` constructor, the one case that
-- *does* typecheck (`hxSwap := .none`) silently resolves to `Option.none`
-- (absent) instead of `some HxSwap.none` -- a footgun with no matching
-- upside. `hxSwap` keeps `some .outerHTML`/`some .none` explicit.

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

end Htmx
