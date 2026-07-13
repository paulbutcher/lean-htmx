/-!
Route pattern strings (`"/users/:id:Nat/posts/:slug:String"`) parsed into
`List PathSeg`. See `docs/routing-design-plan.md` §3 for why this parser is
hand-rolled structural recursion over `List Char` rather than
`String.splitOn`: on this toolchain (`v4.31.0`, `String` rebuilt around
`String.Slice`), a `String.splitOn`-based parser does not reduce through
kernel defeq, which silently breaks `HandlerType`-computed types (`Handler.lean`)
built from its output. A hand-rolled `List Char` recursion was confirmed (by
the throwaway spike behind this design doc) to reduce fine.
-/

namespace Routing

/-- The two capture types supported in v1. Closed by design for now --
whether to open this into a typeclass is deferred, see
`docs/routing-design-plan.md` §5. -/
inductive CaptureKind where
  | nat
  | string
deriving Repr, DecidableEq

/-- The Lean `Type` a capture of this kind produces. Marked `@[reducible]`
because typeclass search uses stricter transparency than ordinary
elaboration and can otherwise fail to see through this even where `rfl`
succeeds -- see `docs/routing-design-plan.md` §4. -/
@[reducible] def CaptureKind.type : CaptureKind → Type
  | .nat => Nat
  | .string => String

/-- The pattern-string spelling of a capture kind (`:id:Nat` / `:id:String`).
Single source of truth for both rendering (`PathSeg.toString`) and parsing
(`parseSeg`), so the two can never drift apart. -/
def CaptureKind.name : CaptureKind → String
  | .nat => "Nat"
  | .string => "String"

/-- One segment of a route path pattern: a literal segment to match
verbatim, or a named, typed capture. -/
inductive PathSeg where
  | lit (s : String)
  | capture (name : String) (kind : CaptureKind)
deriving Repr, DecidableEq

/-- Renders a single segment back to its pattern-string spelling. Built
directly from `List Char` (not string interpolation) so the round-trip
proof below can reason about it structurally. -/
def PathSeg.toString (seg : PathSeg) : String :=
  match seg with
  | .lit s => s
  | .capture name kind =>
      String.ofList (':' :: name.toList ++ ':' :: kind.name.toList)

/-- A segment is well-formed as a *renderable* pattern segment when it
doesn't contain characters that would be re-parsed as a different
structure: no `/` (would split into more segments), and -- for `lit` -- no
leading `:` (would be re-parsed as a capture); for `capture`, no `:` in the
name (would confuse the name/kind split). This is exactly the
precondition `parsePattern_renderPattern` below needs; routes built by
hand from ordinary identifiers naturally satisfy it. -/
def PathSeg.WellFormed : PathSeg → Prop
  | .lit s => s ≠ "" ∧ (∀ c ∈ s.toList, c ≠ '/') ∧ s.toList.head? ≠ some ':'
  | .capture name _ => name ≠ "" ∧ (∀ c ∈ name.toList, c ≠ '/' ∧ c ≠ ':')

/-- Renders a full pattern (list of segments) back to its `"/"`-prefixed
source form, e.g. `[.lit "users", .capture "id" .nat] ↦ "/users/:id:Nat"`.
The empty list renders as the root path `"/"`. -/
def renderPattern (segs : List PathSeg) : String :=
  String.ofList ('/' :: joinWithSlash (segs.map (fun seg => seg.toString.toList)))
where
  /-- Interspaces `'/'` between a list of `List Char` chunks, e.g.
  `[cs₁, cs₂, cs₃] ↦ cs₁ ++ '/' :: cs₂ ++ '/' :: cs₃`. -/
  joinWithSlash : List (List Char) → List Char
    | [] => []
    | [cs] => cs
    | cs :: rest => cs ++ '/' :: joinWithSlash rest

/-- Splits a single first `':'` off a `List Char`, e.g. `"id:Nat".toList`
splits to `("id".toList, "Nat".toList)`. Returns `none` if there is no
second `':'` (a capture segment missing its kind, e.g. bare `:id`). Plain
structural recursion, no `String` operations. -/
def splitOnceColon : List Char → Option (List Char × List Char)
  | [] => none
  | c :: rest =>
      if c = ':' then
        some ([], rest)
      else
        (splitOnceColon rest).map (fun (name, kind) => (c :: name, kind))

/-- Parses one path segment's characters into a `PathSeg`. A segment
starting with `':'` is parsed as a capture (`name:kind`, kind must be a
known `CaptureKind.name`); anything else is a literal. Malformed captures
(missing kind, unknown kind name, empty capture name) fail via `none`,
never a panic -- see the `#guard` regressions below. -/
def parseSeg (cs : List Char) : Option PathSeg :=
  match cs with
  | [] => none
  | c :: rest =>
      if c = ':' then
        match splitOnceColon rest with
        | none => none
        | some ([], _) => none
        | some (nameChars, kindChars) =>
            let kindStr := String.ofList kindChars
            if kindStr = CaptureKind.nat.name then
              some (.capture (String.ofList nameChars) .nat)
            else if kindStr = CaptureKind.string.name then
              some (.capture (String.ofList nameChars) .string)
            else
              none
      else
        some (.lit (String.ofList (c :: rest)))

/-- Splits a `List Char` on `'/'`, e.g. `"a/bc/d".toList` splits to
`[['a'], ['b','c'], ['d']]`. A structural recursion over `List Char`, never
`String.splitOn` -- see the module docstring. -/
def splitChars : List Char → List (List Char)
  | [] => [[]]
  | c :: rest =>
      if c = '/' then
        [] :: splitChars rest
      else
        match splitChars rest with
        | [] => [[c]]
        | seg :: segs => (c :: seg) :: segs

/-- Parses a list of already-split segment character-lists into `PathSeg`s,
failing the whole pattern if any one segment fails (e.g. an empty segment
from a doubled or trailing `/`, or a malformed capture). Hand-rolled rather
than `List.mapM` so the round-trip proof can induct on it directly. -/
def mapSegs : List (List Char) → Option (List PathSeg)
  | [] => some []
  | cs :: rest => (parseSeg cs).bind (fun seg => (mapSegs rest).map (seg :: ·))

/-- Parses a full route pattern string (must start with `"/"`) into path
segments. The root path `"/"` parses to `[]`; anything not starting with
`"/"`, or containing an empty segment (doubled or trailing `/`), or an
unparseable segment, fails via `none`. -/
def parsePattern (s : String) : Option (List PathSeg) :=
  match s.toList with
  | ['/'] => some []
  | '/' :: rest => mapSegs (splitChars rest)
  | _ => none

/-- Parses a route pattern, panicking on a malformed pattern. Intended only
for pattern strings written as source-code literals by the route author
(so a malformed pattern is a programming error caught immediately at
startup), never for untrusted input. -/
def parsePattern! (s : String) : List PathSeg :=
  (parsePattern s).getD []

-- #guard tests: well-formed patterns.
#guard parsePattern "/" = some []
#guard parsePattern "/users" = some [.lit "users"]
#guard parsePattern "/users/:id:Nat" = some [.lit "users", .capture "id" .nat]
#guard parsePattern "/users/:id:Nat/posts/:slug:String"
  = some [.lit "users", .capture "id" .nat, .lit "posts", .capture "slug" .string]

-- #guard tests: malformed patterns fail via `none`, never a panic (§3/§6).
#guard parsePattern "" = none                        -- no leading '/'
#guard parsePattern "users/:id:Nat" = none            -- no leading '/'
#guard parsePattern "/users//id" = none                -- doubled '/' ⇒ empty segment
#guard parsePattern "/users/" = none                   -- trailing '/' ⇒ empty segment
#guard parsePattern "/users/:id:Bool" = none           -- unknown capture kind
#guard parsePattern "/users/:id" = none                -- missing capture kind
#guard parsePattern "/users/::Nat" = none              -- empty capture name

/-! ## Round-trip: `renderPattern` and `parsePattern` are mutual inverses

Dispatch and capture typing are already guaranteed by `HandlerType`/the
equation compiler (`Handler.lean`) -- no proof needed there, typing gives
it for free. This parser is hand-written specifically because the stdlib
path (`String.splitOn`) failed (module docstring), so its correctness is
not implied by anything else in this design and gets its own proof, per
`docs/routing-design-plan.md` §6. -/

private theorem splitOnceColon_append (name tail : List Char)
    (h : ∀ c ∈ name, c ≠ ':') :
    splitOnceColon (name ++ ':' :: tail) = some (name, tail) := by
  induction name with
  | nil => simp [splitOnceColon]
  | cons c name' ih =>
    have hc : c ≠ ':' := h c (by simp)
    have hname' : ∀ c' ∈ name', c' ≠ ':' := fun c' hmem => h c' (by simp [hmem])
    show splitOnceColon ((c :: name') ++ ':' :: tail) = some (c :: name', tail)
    simp only [List.cons_append, splitOnceColon, if_neg hc]
    rw [ih hname']
    rfl

private theorem splitChars_noSlash : ∀ (cs : List Char), (∀ c ∈ cs, c ≠ '/') →
    splitChars cs = [cs]
  | [], _ => rfl
  | c :: cs', h => by
    have hc : c ≠ '/' := h c (by simp)
    have hcs' : ∀ c' ∈ cs', c' ≠ '/' := fun c' hmem => h c' (by simp [hmem])
    have ih := splitChars_noSlash cs' hcs'
    show splitChars (c :: cs') = [c :: cs']
    simp only [splitChars, if_neg hc, ih]

private theorem splitChars_append_slash : ∀ (cs rest : List Char),
    (∀ c ∈ cs, c ≠ '/') → splitChars (cs ++ '/' :: rest) = cs :: splitChars rest
  | [], rest, _ => by simp [splitChars]
  | c :: cs', rest, h => by
    have hc : c ≠ '/' := h c (by simp)
    have hcs' : ∀ c' ∈ cs', c' ≠ '/' := fun c' hmem => h c' (by simp [hmem])
    have ih := splitChars_append_slash cs' rest hcs'
    show splitChars ((c :: cs') ++ '/' :: rest) = (c :: cs') :: splitChars rest
    simp only [List.cons_append, splitChars, if_neg hc, ih]

private theorem splitChars_joinWithSlash : ∀ (css : List (List Char)),
    (∀ cs ∈ css, ∀ c ∈ cs, c ≠ '/') → css ≠ [] →
    splitChars (renderPattern.joinWithSlash css) = css
  | [], _, hne => absurd rfl hne
  | [cs], h, _ => by
    have hcs : ∀ c ∈ cs, c ≠ '/' := h cs (by simp)
    simpa [renderPattern.joinWithSlash] using splitChars_noSlash cs hcs
  | cs :: cs' :: rest, h, _ => by
    have hcs : ∀ c ∈ cs, c ≠ '/' := h cs (by simp)
    have hrest : ∀ cs'' ∈ (cs' :: rest), ∀ c ∈ cs'', c ≠ '/' :=
      fun cs'' hmem => h cs'' (by simp [hmem])
    have ih := splitChars_joinWithSlash (cs' :: rest) hrest (by simp)
    show splitChars (cs ++ '/' :: renderPattern.joinWithSlash (cs' :: rest)) = cs :: cs' :: rest
    rw [splitChars_append_slash cs _ hcs, ih]

private theorem parseSeg_toString (seg : PathSeg) (h : seg.WellFormed) :
    parseSeg seg.toString.toList = some seg := by
  cases seg with
  | lit s =>
    obtain ⟨hne, _hnoslash, hnocolon⟩ := h
    match hs : s.toList with
    | [] => exact absurd (String.toList_eq_nil_iff.mp hs) hne
    | c :: rest =>
      have hc : c ≠ ':' := by
        intro hcolon
        exact hnocolon (by simp [hs, hcolon])
      show parseSeg (c :: rest) = some (PathSeg.lit s)
      simp only [parseSeg, if_neg hc]
      rw [← hs, String.ofList_toList]
  | capture name kind =>
    obtain ⟨hne, hcond⟩ := h
    have hnocolon : ∀ c ∈ name.toList, c ≠ ':' := fun c hmem => (hcond c hmem).2
    show parseSeg (String.ofList (':' :: name.toList ++ ':' :: kind.name.toList)).toList
      = some (PathSeg.capture name kind)
    rw [String.toList_ofList]
    show parseSeg (':' :: (name.toList ++ ':' :: kind.name.toList)) = some (PathSeg.capture name kind)
    simp only [parseSeg, if_true]
    rw [splitOnceColon_append name.toList kind.name.toList hnocolon]
    have hnameNil : name.toList ≠ [] := fun heq => hne (String.toList_eq_nil_iff.mp heq)
    obtain ⟨c, cs, hname⟩ := List.exists_cons_of_ne_nil hnameNil
    have hname_ofList : String.ofList (c :: cs) = name := by rw [← hname, String.ofList_toList]
    simp only [hname, hname_ofList]
    cases kind with
    | nat => simp [CaptureKind.name]
    | string => simp [CaptureKind.name]

private theorem mapSegs_toString : ∀ (segs : List PathSeg), (∀ seg ∈ segs, seg.WellFormed) →
    mapSegs (segs.map (fun seg => seg.toString.toList)) = some segs
  | [], _ => rfl
  | seg :: segs', h => by
    have hseg : seg.WellFormed := h seg (by simp)
    have hsegs' : ∀ seg' ∈ segs', seg'.WellFormed := fun seg' hmem => h seg' (by simp [hmem])
    show mapSegs (seg.toString.toList :: segs'.map (fun seg => seg.toString.toList)) = some (seg :: segs')
    simp only [mapSegs, parseSeg_toString seg hseg, Option.bind_some,
      mapSegs_toString segs' hsegs', Option.map_some]

/-- **The round-trip property, and the main piece of formal verification in
this file**: rendering a well-formed list of path segments back to a
pattern string, then parsing that string, recovers exactly the original
segments. Together with the `#guard` regressions above (malformed input
never panics, always fails via `none`), this is the correctness guarantee
`docs/routing-design-plan.md` §6 asks for -- unlike dispatch/capture
typing, nothing about the equation compiler gives this to us for free. -/
theorem parsePattern_renderPattern (segs : List PathSeg) (h : ∀ seg ∈ segs, seg.WellFormed) :
    parsePattern (renderPattern segs) = some segs := by
  have htoList : (renderPattern segs).toList
      = '/' :: renderPattern.joinWithSlash (segs.map (fun seg => seg.toString.toList)) := by
    unfold renderPattern
    rw [String.toList_ofList]
  rcases segs with _ | ⟨seg, segs'⟩
  · show parsePattern (renderPattern []) = some []
    have hs : (renderPattern ([] : List PathSeg)).toList = ['/'] := by rw [htoList]; rfl
    unfold parsePattern
    rw [hs]
    rfl
  · have hkindNoSlash : ∀ (kind : CaptureKind) c, c ∈ kind.name.toList → c ≠ '/' := by
      intro kind
      cases kind <;> decide
    have hcssNe : (seg :: segs').map (fun s => s.toString.toList) ≠ [] := by simp
    have hnoSlash : ∀ cs ∈ (seg :: segs').map (fun s => s.toString.toList),
        ∀ c ∈ cs, c ≠ '/' := by
      intro cs hcs c hc
      simp only [List.mem_map] at hcs
      obtain ⟨seg', hseg'mem, hseg'eq⟩ := hcs
      have hwf := h seg' hseg'mem
      cases seg' with
      | lit s =>
        obtain ⟨_, hnoslash, _⟩ := hwf
        subst hseg'eq
        exact hnoslash c hc
      | capture name kind =>
        obtain ⟨_, hcond⟩ := hwf
        subst hseg'eq
        simp only [PathSeg.toString, String.toList_ofList, List.mem_cons, List.mem_append] at hc
        rcases hc with (rfl | hc) | (rfl | hc)
        · decide
        · exact (hcond c hc).1
        · decide
        · exact hkindNoSlash kind c hc
    have hrest : renderPattern.joinWithSlash ((seg :: segs').map (fun s => s.toString.toList))
        ≠ [] := by
      cases segs' with
      | nil =>
        have hsegWF := h seg (by simp)
        have hne : seg.toString ≠ "" := by
          cases seg with
          | lit s => exact hsegWF.1
          | capture name kind => simp [PathSeg.toString]
        simp only [renderPattern.joinWithSlash, List.map_cons, List.map_nil]
        exact fun heq => hne (String.toList_eq_nil_iff.mp heq)
      | cons seg' segs'' =>
        simp [renderPattern.joinWithSlash]
    obtain ⟨c0, r0, hcr0⟩ := List.exists_cons_of_ne_nil hrest
    have hs : (renderPattern (seg :: segs')).toList = '/' :: c0 :: r0 := by
      rw [htoList, hcr0]
    show parsePattern (renderPattern (seg :: segs')) = some (seg :: segs')
    unfold parsePattern
    rw [hs]
    show mapSegs (splitChars (c0 :: r0)) = some (seg :: segs')
    rw [← hcr0, splitChars_joinWithSlash _ hnoSlash hcssNe, mapSegs_toString (seg :: segs') h]

end Routing
