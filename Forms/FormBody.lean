import Std.Http.Server

/-!
Decoding an `application/x-www-form-urlencoded` request body (`title=Buy+milk`) into
`(name, value)` pairs, and reading that body straight off an incoming request.

Hand-rolled structural recursion over `List Char`, deliberately not `String.splitOn` -- the same
choice `Routing/Pattern.lean` made for pattern strings, for the same reason: this toolchain's
`String.splitOn` doesn't play well with the kind of char-by-char processing percent-decoding also
needs (turning `%XX` into a single decoded character as it goes), so one uniform `List Char`
recursion handles splitting *and* decoding rather than mixing `String.splitOn` with a separate
decode pass.

This module only exists because `Routing/Server.lean` threads the full `Request Body.Stream` into
every handler (`Result := Request Body.Stream → ContextAsync (Response Body.Any)`) -- once a
handler can call `request.body.readAll (α := String)` to get the raw body, something has to turn
that into `(name, value)` pairs, and `Std.Http.URI`'s query-string types aren't a fit (see
`docs/todo-app-plan.md`: `URI.EncodedQueryString`'s constructor is `private` with a validity proof
obligation, built for parsing URIs, not for reinterpreting an arbitrary body string).
-/

namespace Forms

open Std Async
open Std Http Server

/-- One hex digit's numeric value (case-insensitive), or `none` if `c` isn't `[0-9a-fA-F]`. -/
private def hexDigit (c : Char) : Option Nat :=
  let n := c.toNat
  if n ≥ '0'.toNat ∧ n ≤ '9'.toNat then some (n - '0'.toNat)
  else if n ≥ 'a'.toNat ∧ n ≤ 'f'.toNat then some (n - 'a'.toNat + 10)
  else if n ≥ 'A'.toNat ∧ n ≤ 'F'.toNat then some (n - 'A'.toNat + 10)
  else none

/-- Percent-decodes a `List Char`, accumulating the (reversed) decoded output in `acc`: `+`
becomes a space, `%XX` becomes the single character with that codepoint, and a `%` not followed by
two valid hex digits (including one at the very end of the input) is passed through literally
rather than failing the whole decode -- form bodies in the wild are usually decoded tolerantly,
and this is a demo app's input path, not a place to panic on a stray `%`. -/
private def decodeCharsAux : List Char → List Char → List Char
  | acc, [] => acc.reverse
  | acc, '+' :: rest => decodeCharsAux (' ' :: acc) rest
  | acc, '%' :: d1 :: d2 :: rest =>
    match hexDigit d1, hexDigit d2 with
    | some h1, some h2 => decodeCharsAux (Char.ofNat (h1 * 16 + h2) :: acc) rest
    | _, _ => decodeCharsAux ('%' :: acc) (d1 :: d2 :: rest)
  | acc, c :: rest => decodeCharsAux (c :: acc) rest

/-- Percent-decodes one form-urlencoded component (a key or a value). -/
def decodeComponent (s : String) : String :=
  String.ofList (decodeCharsAux [] s.toList)

/-- Splits a `List Char` on `'&'`, mirroring `Pattern.lean`'s `splitChars` (which does the same
job for `'/'`). -/
private def splitAmp : List Char → List (List Char)
  | [] => [[]]
  | c :: rest =>
    if c = '&' then [] :: splitAmp rest
    else
      match splitAmp rest with
      | [] => [[c]]
      | seg :: segs => (c :: seg) :: segs

/-- Splits a `List Char` on the first `'='`. A pair with no `'='` at all (a bare flag, e.g.
`"checked"`) is treated as that key with an empty value -- unlike `Pattern.lean`'s
`splitOnceColon`, this never fails: forms legitimately send valueless keys. -/
private def splitOnceEquals : List Char → List Char × List Char
  | [] => ([], [])
  | '=' :: rest => ([], rest)
  | c :: rest =>
    let (k, v) := splitOnceEquals rest
    (c :: k, v)

/-- Decodes an `application/x-www-form-urlencoded` body into `(name, value)` pairs, in the order
they appeared. A completely empty body (or a stray `&` producing an empty segment) contributes no
pairs, rather than an empty-string key. -/
def parseFormBody (body : String) : List (String × String) :=
  (splitAmp body.toList).filterMap fun cs =>
    if cs.isEmpty then none
    else
      let (k, v) := splitOnceEquals cs
      some (decodeComponent (String.ofList k), decodeComponent (String.ofList v))

/-- Reads and decodes a `application/x-www-form-urlencoded` request body, returning the value of
`name`, or `""` if the body has no such field. -/
def formField (req : Request Body.Stream) (name : String) : Async String := do
  let body ← req.body.readAll (α := String)
  return ((parseFormBody body).lookup name).getD ""

-- #guard tests: empty body, single/multiple pairs, `+`-as-space, `%XX` decoding (including
-- decoding a literal `%` via `%25`), a valueless flag, an empty value, and tolerant handling of a
-- malformed/trailing `%` escape.
#guard parseFormBody "" = []
#guard parseFormBody "title=Buy+milk" = [("title", "Buy milk")]
#guard parseFormBody "a=1&b=2" = [("a", "1"), ("b", "2")]
#guard parseFormBody "title=Buy%20milk" = [("title", "Buy milk")]
#guard parseFormBody "a=100%25" = [("a", "100%")]
#guard parseFormBody "flag" = [("flag", "")]
#guard parseFormBody "empty=&x=1" = [("empty", ""), ("x", "1")]
#guard parseFormBody "a=b%" = [("a", "b%")]
#guard parseFormBody "a=b%zz" = [("a", "b%zz")]

end Forms
