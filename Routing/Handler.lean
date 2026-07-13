import Routing.Pattern

/-!
Computing a handler's function type from a route pattern, and dispatching
a decoded request path against it. See `docs/routing-design-plan.md` §2:
the throwaway spike behind that design doc confirmed (by direct
compilation, not just reasoning about it) that `HandlerType` reduces
through ordinary kernel defeq (`rfl`) with **zero extra machinery** -- no
macro, no typeclass dispatch step -- which is what lets a wrong-arity
handler be rejected as an ordinary compile-time type error (the
`#guard_msgs` regression below), the same way Servant's type-level
encoding does in Haskell, but without needing DataKinds/type families to
fake a type depending on a value.
-/

namespace Routing

/-- The Lean function type a handler for `segs` must have: one argument
per capture segment (typed via `CaptureKind.type`), literal segments
contribute nothing to the arity, and the whole thing returns `result`. -/
def HandlerType (segs : List PathSeg) (result : Type) : Type :=
  match segs with
  | [] => result
  | .lit _ :: rest => HandlerType rest result
  | .capture _ kind :: rest => kind.type → HandlerType rest result

/-- Matches a decoded request path (`List String`, e.g. from
`RequestTarget.path.toDecodedSegments`) against `segs`, applying `handler`
to the extracted, typed capture values as it goes. `none` on a literal
mismatch, a path segment that doesn't parse as the capture's type (e.g.
`"notanumber"` against a `.nat` capture), or an arity mismatch between
`segs` and the actual path. There's no automatic derivation for this step
(unlike Servant's `HasServer` instance search) -- it's a real, accepted
cost of not having macros do the work, per `docs/routing-design-plan.md`
§2. -/
def dispatch {result : Type} :
    (segs : List PathSeg) → HandlerType segs result → List String → Option result
  | [], h, [] => some h
  | .lit s :: rest, h, p :: ps => if s == p then dispatch rest h ps else none
  | .capture _ .nat :: rest, h, p :: ps => p.toNat?.bind (fun n => dispatch rest (h n) ps)
  | .capture _ .string :: rest, h, p :: ps => dispatch rest (h p) ps
  | _, _, _ => none

private def userPattern : List PathSeg := parsePattern! "/users/:id:Nat"

private def userHandler : HandlerType userPattern String :=
  fun (id : Nat) => s!"user #{id}"

-- #guard tests: dispatch success, mistyped capture, literal mismatch, arity mismatch.
#guard dispatch userPattern userHandler ["users", "42"] = some "user #42"
#guard dispatch userPattern userHandler ["users", "notanumber"] = none
#guard dispatch userPattern userHandler ["posts", "42"] = none          -- literal mismatch
#guard dispatch userPattern userHandler ["users"] = none                -- too few path segments
#guard dispatch userPattern userHandler ["users", "42", "extra"] = none -- too many path segments

-- Negative-compile regression (§2): a wrong-arity handler against a real
-- pattern is rejected at compile time, pointing at the actual value
-- mismatch -- this is the whole payoff of computing the handler's type
-- from pattern data instead of hand-writing/documenting the arity.
/--
error: Type mismatch
  fun _id _extra => "oops"
has type
  Nat → String → String
but is expected to have type
  HandlerType userPattern String
-/
#guard_msgs in
def badArity : HandlerType userPattern String :=
  fun (_id : Nat) (_extra : String) => "oops"

end Routing
