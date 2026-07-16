import Htmx.Attrs

/-!
Tests for `Htmx.Attrs`.
-/

namespace HtmxTests

open Htmx

-- #guard tests, one (or more) per field. Optional `String`/`Bool` fields
-- are set via the `Coe` instances above, not `some`.
#guard HtmxAttrs.toPairs {} = []
#guard HtmxAttrs.toPairs { hxGet := "/x" } = [("hx-get", "/x")]
#guard HtmxAttrs.toPairs { hxPost := "/x" } = [("hx-post", "/x")]
#guard HtmxAttrs.toPairs { hxPut := "/x" } = [("hx-put", "/x")]
#guard HtmxAttrs.toPairs { hxPatch := "/x" } = [("hx-patch", "/x")]
#guard HtmxAttrs.toPairs { hxDelete := "/x" } = [("hx-delete", "/x")]
#guard HtmxAttrs.toPairs { hxTrigger := "click" } = [("hx-trigger", "click")]
#guard HtmxAttrs.toPairs { hxTarget := "#result" } = [("hx-target", "#result")]
-- No `Coe HxSwap (Option HxSwap)` (see that decision's comment above) --
-- `hxSwap` stays `some`-explicit.
#guard HtmxAttrs.toPairs { hxSwap := some .outerHTML } = [("hx-swap", "outerHTML")]
#guard HtmxAttrs.toPairs { hxSwap := some .none } = [("hx-swap", "none")]
#guard HtmxAttrs.toPairs { hxSwapOob := "true" } = [("hx-swap-oob", "true")]
#guard HtmxAttrs.toPairs { hxSelect := "#x" } = [("hx-select", "#x")]
#guard HtmxAttrs.toPairs { hxSelectOob := "#x" } = [("hx-select-oob", "#x")]
#guard HtmxAttrs.toPairs { hxPushUrl := "true" } = [("hx-push-url", "true")]
#guard HtmxAttrs.toPairs { hxConfirm := "Sure?" } = [("hx-confirm", "Sure?")]
#guard HtmxAttrs.toPairs { hxIndicator := "#spinner" } = [("hx-indicator", "#spinner")]
#guard HtmxAttrs.toPairs { hxVals := "{\"x\":1}" } = [("hx-vals", "{\"x\":1}")]
#guard HtmxAttrs.toPairs { hxBoost := true } = [("hx-boost", "true")]
#guard HtmxAttrs.toPairs { hxBoost := false } = [("hx-boost", "false")]  -- explicit, not omitted
#guard HtmxAttrs.toPairs { hxExt := "json-enc" } = [("hx-ext", "json-enc")]
#guard HtmxAttrs.toPairs { hxParams := "*" } = [("hx-params", "*")]

#guard HtmxAttrs.toPairs { hxGet := "/x", hxTarget := "#y", hxSwap := some .innerHTML }
  = [("hx-get", "/x"), ("hx-target", "#y"), ("hx-swap", "innerHTML")]

end HtmxTests
