/-!
Escaping and low-level attribute rendering. See `docs/html-library-plan.md`
Phase 2 for the design rationale, and the Phase 0 throwaway spike (recorded
there) for why the proofs below are structured this way.
-/

namespace Html

/-- Escapes `&`, `<`, `>`, `"` for safe inclusion in HTML text content or
inside a double-quoted attribute value. `&` must be replaced first: it's
the character every other replacement introduces, so escaping it *after*
`<`/`>`/`"` would corrupt their replacements (`&lt;` escaped a second time
would become `&amp;lt;`). This function fixes the order once, correctly,
rather than leaving it as a comment on every call site. -/
def escapeChar (c : Char) : String :=
  match c with
  | '&' => "&amp;"
  | '<' => "&lt;"
  | '>' => "&gt;"
  | '"' => "&quot;"
  | c    => String.singleton c

/-- Escape a whole string by escaping each character (a structural fold
over `List Char`, not a chain of `String.replace` — see
`docs/html-library-plan.md` 1.7: this shape is what makes `escape_safe`
below inductive-friendly in core Lean without Mathlib). -/
def escape (s : String) : String :=
  String.join (s.toList.map escapeChar)

/-- Internal, `Bool`-valued (core Lean does not synthesize
`Decidable (∀ c ∈ l, P c)` for a `Prop`-valued predicate built from `∨`/`=`,
so `decide` needs this to be computable from the start; see Phase 0 spike
notes). Not part of the public API — `escape_safe` below is. -/
private def isDangerous (c : Char) : Bool := c == '<' || c == '>' || c == '"'

private theorem escapeChar_clean (c : Char) :
    ∀ c' ∈ (escapeChar c).toList, isDangerous c' = false := by
  unfold escapeChar
  split
  case h_1 => decide
  case h_2 => decide
  case h_3 => decide
  case h_4 => decide
  case h_5 =>
    intro c' hc'
    simp only [String.toList_singleton, List.mem_singleton] at hc'
    subst hc'
    unfold isDangerous
    simp_all

private theorem join_toList (l : List String) :
    ∀ acc : String, (l.foldl (· ++ ·) acc).toList = acc.toList ++ (l.map String.toList).flatten := by
  induction l with
  | nil => simp
  | cons a as ih =>
    intro acc
    simp only [List.foldl_cons, List.map_cons, List.flatten_cons]
    rw [ih (acc ++ a)]
    simp [String.toList_append, List.append_assoc]

/-- **The XSS-relevant safety property, and the main piece of formal
verification in this library**: `escape`'s output never contains a raw
(unescaped) `<`, `>`, or `"`. This is what makes double-quote-delimited,
escaped attribute values and escaped text content safe against markup
breakout — see `renderAttr` below for the paired renderer-side invariant
this depends on. -/
theorem escape_safe (s : String) : ∀ c ∈ (escape s).toList, c ≠ '<' ∧ c ≠ '>' ∧ c ≠ '"' := by
  unfold escape String.join
  intro c hc
  rw [join_toList] at hc
  simp only [String.toList_empty, List.nil_append, List.mem_flatten, List.mem_map] at hc
  obtain ⟨cs, ⟨s0, ⟨c0, _hc0mem, hs0eq⟩, hcs0eq⟩, hcmem⟩ := hc
  have h := escapeChar_clean c0 c (hs0eq ▸ hcs0eq ▸ hcmem)
  unfold isDangerous at h
  simp only [Bool.or_eq_false_iff, beq_eq_false_iff_ne, ne_eq] at h
  exact ⟨h.1.1, h.1.2, h.2⟩

private theorem foldl_append_eq (l : List String) :
    ∀ acc : String, l.foldl (· ++ ·) acc = acc ++ l.foldl (· ++ ·) "" := by
  induction l with
  | nil => simp
  | cons a as ih =>
    intro acc
    simp only [List.foldl_cons, String.empty_append]
    rw [ih a, ih (acc ++ a), String.append_assoc]

private theorem join_append (l1 l2 : List String) :
    String.join (l1 ++ l2) = String.join l1 ++ String.join l2 := by
  unfold String.join
  rw [List.foldl_append, foldl_append_eq l2]

/-- Compositionality: escaping two fragments and concatenating the results
is the same as escaping their concatenation directly. No double-escaping
and no under-escaping happens at the fragment boundary — this is the
formal version of the "`&` must go first" ordering note on `escapeChar`. -/
theorem escape_append (a b : String) : escape (a ++ b) = escape a ++ escape b := by
  unfold escape
  rw [String.toList_append, List.map_append, join_append]

/-- Render one attribute as `name="escaped value"`, with a leading space
so callers can concatenate these directly after a tag name. Attribute
values are *always* double-quote-delimited — this renderer never emits
unquoted or single-quoted attribute syntax. HTML5 permits unquoted
attribute values, but `escape_safe` only rules out raw `<`/`>`/`"`; an
unquoted value could still be broken out of by a bare space or `>`, so
this delimiting choice is a load-bearing precondition of the safety
guarantee above, not a stylistic default. -/
def renderAttr (name value : String) : String :=
  s!" {name}=\"{escape value}\""

end Html
