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
(in `Tests.Escape`) inductive-friendly in core Lean without Mathlib). -/
def escape (s : String) : String :=
  String.join (s.toList.map escapeChar)

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
