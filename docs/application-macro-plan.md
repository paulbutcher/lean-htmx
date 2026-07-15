# `application`: a route-tree macro producing a bundled `Application` value

Context for a fresh session: `Routing` (`Routing.lean`, `docs/routing-design-plan.md`) is a typed
path router — `route method pattern handler` builds a `Route`, `HandlerType` rejects a
wrong-arity/wrong-type handler at compile time. Reverse routing (`Routing/Url.lean`, `routeUrl`)
generates a typed URL-builder from the same pattern string. Both are ordinary `def`s, no macros.
This doc plans the next layer: a single `application` declaration that reads as a route tree
(pattern nesting shared, methods and handlers inline) and produces one value bundling the
dispatch handler and a generated reverse-routing `Urls` struct — no more hand-written
`Todo/Routes.lean` constants, no more separately-maintained pattern strings.

**Read this whole doc before writing code.** It corrects a design mistake made and caught in the
same conversation that produced it — the corrected version, not the false start, is what's
authoritative. §7 is the task checklist; everything above it is rationale a fresh session needs to
not redo already-settled reasoning.

## 0. Prior art: this was attempted once already, then reverted

`git log --all` on this repo shows two commits — `6ed4572` ("Reverse routing plan", adding
`docs/reverse-routing-macro-plan.md` + a task list) and `0b2ae6a` ("Nicer reverse routing", adding
`Routing/RoutesMacro.lean`, a working, tested `routes!` command macro) — both reverted immediately
after (`a8a3cdc`, `145df63`), with no rationale recorded in either revert's commit message. The
reverted implementation is still recoverable: `git show a8a3cdc^:Routing/RoutesMacro.lean`.

That version is **real, working prior art**, not a discarded dead end — it solved the hard parsing
problems this doc's macro also needs solved, and its solutions transfer directly (§4). What it
*didn't* solve, and what this doc's design changes:

- Its `Urls` struct had to be hand-declared by the caller; the macro only produced the *value*
  (`docs/reverse-routing-macro-plan.md` §6.2 explains why: a term can't be pre-declared without a
  pre-existing type, and the doc didn't consider generating the struct itself). This doc's version
  generates the struct too (§3).
- Its context (`db : SQLite`) stayed a loose curried parameter on a separate `routes` def, wired
  up by hand in `main`. This doc bundles context and URLs into one `Application` value.

Don't re-derive `docs/reverse-routing-macro-plan.md` §2-§5's grammar reasoning (nested fragments,
why flat/grouped alternatives were rejected) — it's settled, and §4 below inherits it directly.

## 1. The request, and the correction mid-design

Target ergonomics (paraphrased from the original ask):

```lean
application app : SQLite where
  "/" as index { get => pageHandler .all }
  "/active" as active { get => pageHandler .active }
  "/todos" as todos {
    post => addHandler
    "/:id:Nat" as todo {
      put => saveHandler
      delete => deleteHandler
      "/edit" as todoEdit { get => editHandler }
      "/toggle" as todoToggle { post => toggleHandler }
    }
    "/toggle-all" as toggleAll { post => toggleAllHandler }
    "/clear-completed" as clearCompleted { delete => clearCompletedHandler }
  }
```

producing `app : Application SQLite AppUrls` with `app.urls.todo 7 = "/todos/7"` etc.

**First-pass design mistake, caught before implementation:** treating `SQLite` above as a context
*value* (like the already-open `db` handle `main` creates via `SQLite.open`, an effectful action)
implied `application` had to be usable as an ordinary local term inside `main`'s `do`-block — but
generating a fresh `structure AppUrls` is a command-level effect (new type declarations don't exist
in term position), which a `let`-bound term inside `do` can't do. Chasing that led to genuinely
awkward alternatives (hand-declaring `Urls` again just to dodge the conflict, or passing the whole
self-referential `Application` — including its own not-yet-built `handler` field — into every route
handler, which needs `partial`/knot-tying for a field no handler legitimately reads).

**The actual fix (confirmed with the request's author): `SQLite` here is a *type*, not a value.**
`application` only ever sees the context's *type* at macro-expansion time; the concrete context
*value* is supplied later, by whoever wires the finished handler into the server — i.e.
`Application.handler` has type `Ctx → StatelessHandler`, not `StatelessHandler`. This removes both
problems at once:

- No self-reference. `handler := fun (ctx : Ctx) => toHandler [...]` closes over `ctx` (a lambda
  parameter) and `urls` (an already-fully-built local value) — neither depends on the
  `Application` value being constructed, so the structure literal is perfectly ordinary.
- No term/command conflict. `application` is unambiguously a top-level command (§2) — it never
  needs to run inside `main`'s `do`-block, because it never touches the actual `db` handle.
  `main` supplies that at the one place it's actually needed:

  ```lean
  def main : IO Unit := Async.block do
    let db ← SQLite.open ":memory:"
    Todo.initSchema db
    let addr := .v4 ⟨.ofParts 127 0 0 1, 2000⟩
    serve addr (app.handler db) >>= waitShutdown
  ```

## 2. Target structures and macro surface syntax

```lean
-- Routing/Application.lean, permanent, app-framework-agnostic (same principle as the rest of
-- Routing — this file must not import Todo/SQLite).
structure Application (Ctx Urls : Type) where
  urls    : Urls
  handler : Ctx → StatelessHandler
```

**Surface syntax deviates deliberately from the original `def app := application SQLite where`
sketch.** Extending Lean's own `def` grammar to recognize a special right-hand side is fragile and
not how the reverted spike did it (`docs/reverse-routing-macro-plan.md`'s `routes!` used its own
leading keyword, not a `def`-grammar hook). Use a dedicated leading-keyword command instead, taking
the binding name and context type before `where`, mirroring `routes! (db : SQLite) : Todo.Urls
where` exactly:

```lean
application app : SQLite where
  "/" as index { get => pageHandler .all }
  ...
```

This expands (§3) to two spliced top-level commands: `structure AppUrls where ...` and
`def app : Application SQLite AppUrls := ...`. If the two-word `application app : SQLite where`
reads awkwardly once real code is in front of you, revisit the exact keyword/argument order then —
not worth relitigating on paper before it's been typed once for real.

## 3. What it expands to

```lean
structure AppUrls where
  index          : String
  active         : String
  todos          : String
  todo           : Nat → String
  todoEdit       : Nat → String
  todoToggle     : Nat → String
  toggleAll      : String
  clearCompleted : String

def app : Routing.Application SQLite AppUrls :=
  let urls : AppUrls :=
    { index := Routing.routeUrl "/",
      active := Routing.routeUrl "/active",
      todos := Routing.routeUrl "/todos",
      todo := Routing.routeUrl "/todos/:id:Nat",
      todoEdit := Routing.routeUrl "/todos/:id:Nat/edit",
      todoToggle := Routing.routeUrl "/todos/:id:Nat/toggle",
      toggleAll := Routing.routeUrl "/todos/toggle-all",
      clearCompleted := Routing.routeUrl "/todos/clear-completed" }
  { urls := urls
    handler := fun (ctx : SQLite) => Routing.toHandler
      [ Routing.Route.get "/" (pageHandler .all ctx urls),
        Routing.Route.get "/active" (pageHandler .active ctx urls),
        Routing.Route.post "/todos" (addHandler ctx urls),
        Routing.Route.put "/todos/:id:Nat" (saveHandler ctx urls),
        Routing.Route.delete "/todos/:id:Nat" (deleteHandler ctx urls),
        Routing.Route.get "/todos/:id:Nat/edit" (editHandler ctx urls),
        Routing.Route.post "/todos/:id:Nat/toggle" (toggleHandler ctx urls),
        Routing.Route.post "/todos/toggle-all" (toggleAllHandler ctx urls),
        Routing.Route.delete "/todos/clear-completed" (clearCompletedHandler ctx urls) ] }
```

Handler functions therefore take `Ctx → Urls → <captures in pattern order> → Request Body.Stream →
ContextAsync (Response Body.Any)` — e.g. `editHandler (ctx : SQLite) (urls : AppUrls) (id : Nat)
(req : Request Body.Stream) : ContextAsync (Response Body.Any)`. This is a small, mechanical change
from today's handlers (they already take `db` first; this just adds `urls` as the second curried
argument) — see §7 Phase 3.

Generated names are derived from the binder (`app` → `AppUrls`), not fixed literals — the reverted
spike always spliced literal `urls`/`routes` idents (deliberately non-hygienic, needed so
downstream code can reference them), which is fine for one invocation per file but collides if a
file ever has two `application` blocks. Deriving from the user's chosen name avoids that for free.

## 4. Reused unchanged from the reverted spike (`Routing/RoutesMacro.lean`)

Confirmed working by direct compilation there; don't re-spike these, adapt the code directly
(`git show a8a3cdc^:Routing/RoutesMacro.lean`):

- **Grammar.** One `routeItem` syntax category, two productions: `ident " => " term` (a method
  entry) and `str (" as " ident)? " { " manyIndent(routeItem) " } "` (a fragment, recursing into
  itself). A node's body freely mixes both at any depth, including top level.
- **`manyIndent`, not a bare `routeItem*`.** Without it, a handler `term` with nothing to stop it
  greedily continues parsing across a newline as a further application argument, mis-parsing the
  next sibling fragment as an extra argument to the previous handler. `manyIndent` anchors a
  same-or-greater-column check at each item list's own start.
- **Resolve a node's full pattern via `List PathSeg` append, not string concatenation** — sidesteps
  every separator edge case (doubled/trailing `/`) `Pattern.lean`'s own parser has to be careful
  about.
- **Parse with `parsePattern`, never `parsePattern!`, inside macro elaboration.**
  `parsePattern!`'s `(parsePattern s).getD []` silently defaults to the root pattern on malformed
  input rather than panicking (confirmed directly against this toolchain — `panic!` is
  definitionally transparent to `Inhabited.default`, so even a `panic!`-based fallback wouldn't
  fail at the point that matters). The macro must `throwErrorAt` the offending fragment's own
  string literal on `none`, itself — there is no version of `parsePattern!` as an ordinary `def`
  that turns a malformed string into a compile error.
- **Tree-wide duplicate checks.** Two nodes sharing an `as` name anywhere in the tree (not just
  siblings), and two different `as` names resolving to the same full pattern (compared as resolved
  `List PathSeg`, not local text) are both macro-time errors pointing at the second node.
- **Order-sensitivity of the flattened dispatch table.** `dispatchTable` is first-match-wins over a
  flat list; a literal segment (`/todos/toggle-all`) must still beat a same-arity capture
  (`/todos/:id:Nat`) after the tree is flattened. Keep the positive regression that dispatches
  through the macro's *actual* output for exactly this collision, not just a manual click-through.
- **Confirmed error quality.** A wrong-arity handler nested several levels deep still produces a
  real `HandlerType` mismatch pointing at the handler, not an opaque macro-expansion dump — pin this
  with a `#guard_msgs` regression the same way `Handler.lean`'s `badArity` and `Url.lean`'s
  `badUrlArity` already do.
- **`mkIdent`, not a literal name in a quotation**, for every generated identifier — a literal
  identifier written directly in `` `(...) `` is hygienically mangled and invisible outside the
  macro's own expansion.

## 5. What's new here and doesn't have prior-art to lean on

- **Generating `structure AppUrls where ...` itself**, not just a value of a pre-declared type.
  This is genuinely new relative to the reverted spike. **Compute each field's type directly from
  the macro's own `List PathSeg` data, in `CommandElabM`** — a small recursive helper folding
  `.capture _ .nat :: rest ↦ (← `(Nat → $restTy))`, `.capture _ .string :: rest ↦ (← `(String →
  $restTy))`, `[] ↦ `(String)`, terminating segments contribute nothing — rather than emitting
  `Routing.UrlType (Routing.parsePattern! "...")` as the field's type. The latter would work
  (defeq-equal), but `docs/routing-design-plan.md` §4 already found that types *computed* this way
  can fail typeclass/instance-search transparency even when they reduce fine for ordinary
  elaboration (confirmed there: `BEq (HandlerType [] String)` failed to synthesize despite being
  definitionally `String`), and `Routing/Url.lean`'s own test section had to work around exactly
  this for `#guard`-based equality checks on `UrlType`-typed values. Emitting the concrete arrow
  type directly (`Nat → String`, not `UrlType (parsePattern! ...)`) sidesteps that risk entirely for
  every downstream consumer of the generated struct, not just this file's own tests — worth the
  small amount of extra macro code.
- **Two declarations from one invocation now includes a `structure`, not just two `def`s.** The
  reverted spike's `elabCommand` splicing pattern (build a `TSyntax `command`, call `elabCommand`
  on it, once per generated declaration) generalizes directly — a `structure ... where ...`
  quotation is spliced exactly the same way a `def ... := ...` one was. Confirm this works before
  building the full grammar around it (§7 Phase 1).
- **Handler application order.** Every route handler is applied to `ctx urls` (in that order,
  partially, before its captures) rather than the reverted spike's `urls db` — pick one order and
  keep it consistent; `ctx` first matches today's existing handlers' existing `db`-first
  convention (`Main.lean`), minimizing the diff Phase 3 has to make to each one.

## 6. Not in scope

Same exclusions as `Routing.lean`'s existing "Not yet supported" list and
`docs/routing-design-plan.md` §5 — query-string parameters, an open/typeclass `CaptureKind`,
Rails-style `resources`/CRUD-verb inference from a bare name. Nesting itself is the one addition
justified by demonstrated need; don't add further sugar speculatively.

## 7. Task checklist

Follow this repo's `CLAUDE.md` throughout: after editing a `.lean` file, check it with
`mcp__lean-lsp__lean_diagnostic_messages`; after adding/removing an `import`, use
`mcp__lean-lsp__lean_build` instead of (or in addition to) plain `lake build`; ignore editor
`<ide_diagnostics>` hook output (can be stale); `lake build` (and `lake test` for anything touching
`Todo`/`TodoTests`) is final ground truth before considering any task done.

**Read §0-§6 in full before starting.** If something below seems to contradict them, they win —
fix this checklist to match rather than silently deviating.

### Phase 0 — recover and read the prior art

- [ ] `git show a8a3cdc^:Routing/RoutesMacro.lean` and read it in full — this is the nested-grammar
      parsing/hygiene machinery (§4) that this phase adapts, not reinvents. Save a local copy to
      refer back to while writing the new file; don't restore it into the tree as-is (it's built
      around a hand-declared `Urls` and a curried `db`, both superseded by §1-§3).
- [ ] Also skim `git show 6ed4572:docs/reverse-routing-macro-plan.md` for the grammar-alternatives
      reasoning (§2-§3 there) if any of §4's "why" isn't clear from this doc alone.

### Phase 1 — spike the new part in isolation before committing to the full grammar

Goal: confirm a command macro can splice a `structure` command and a `def` command together in
one expansion, with the struct's field types computed from `List PathSeg` directly (§5), before
building the full nested-fragment grammar around it. Do this against a toy example, not `Todo`.

- [ ] New file `Routing/Application.lean`. Define `structure Application (Ctx Urls : Type) where
      urls : Urls; handler : Ctx → StatelessHandler`.
- [ ] In the same file (or a scratch namespace within it), hand-write — no macro yet — the
      *expansion* a two-route toy example should produce (mirroring §3's worked example at small
      scale: one `as`-named leaf, one capturing `as`-named leaf), to confirm the target shape
      type-checks at all before automating its generation.
- [ ] Write the `List PathSeg → CommandElabM (TSyntax `term)` field-type helper described in §5.
      Confirm with a throwaway `#eval`/`elabCommand` test that it produces `Nat → String` (not
      `UrlType (parsePattern! ...)`) for a two-capture pattern, and that a struct field declared
      with the emitted syntax is usable in an ordinary `#guard` equality check with no instance-
      search friction (the exact failure mode `docs/routing-design-plan.md` §4 hit).
- [ ] Confirm `elabCommand` can splice a `structure ... where ...` command the same way the
      reverted spike spliced `def`s (a distinct code path from anything already proven — verify it
      directly, don't assume it generalizes).

### Phase 2 — build the full `application` macro against a toy harness

Mirrors the reverted spike's own test section (`namespace PositiveTest` etc.) — reuse that
structure, adapted for the new surface syntax and generated-struct output.

- [ ] Port the `routeItem` syntax categories and `manyIndent`-based grammar from
      `Routing/RoutesMacro.lean` (§4) into `Routing/Application.lean`, adjusted for the
      `application <name> : <CtxType> where <items>` surface (§2) instead of `routes! (db :
      <dbTy>) : <urlsTy> where`.
- [ ] Implement the tree walk: thread resolved `List PathSeg` down through nested fragments
      (`processItems` in the old file is the template), collecting every `method => handler` entry
      (with resolved segs) and every `as`-named node (with resolved segs), exactly as before.
- [ ] Port the tree-wide duplicate-name and duplicate-pattern checks unchanged (§4).
- [ ] Generate the `structure <Name>Urls where ...` command from the named nodes, using Phase 1's
      field-type helper — one field per `as`-named node, field name = the `as` identifier, field
      type computed from that node's resolved segs.
  - [ ] Generate the `def <name> : Application <CtxType> <Name>Urls := ...` command per §3's shape
        — a `let urls := { ... }` (one entry per named node, value = `routeUrl "<resolved
        pattern>"`), then `{ urls := urls, handler := fun (ctx : <CtxType>) => toHandler [ ... ] }`
        with one list element per method entry, each applying its handler term to `ctx urls` before
        `Route.get`/`.post`/`.put`/`.delete` sees it (§5's ordering decision).
- [ ] Port the positive regression (2-3 levels of nesting, a captured node with two methods sharing
      one written pattern, a same-arity literal/capture collision exercised through the macro's
      actual flattened `dispatchTable` output) — adapt method/handler signatures to the new
      `ctx → urls → captures → req` shape.
- [ ] Port the four negative regressions as `#guard_msgs`: wrong-arity handler, malformed fragment
      text, duplicate `as` name, two names resolving to the same pattern. Confirm the wrong-arity
      error still points at the actual handler/line, not an opaque expansion dump (§4's "confirmed
      error quality" — re-confirm for the new shape, don't assume it carries over unchanged just
      because the old one worked).
- [ ] `lean_diagnostic_messages` on the file, then `lake build`, before moving to Phase 3.

### Phase 3 — migrate the Todo app

This is the same shape of refactor `docs/reverse-routing-macro-plan.md` §6.3 already scoped for
the old design (per-view-function URL threading) — re-derive the call-site list from the *current*
`Todo/Views.lean`, don't assume it still matches that doc's table (files have moved since).

- [ ] Read `Todo/Views.lean`, `Todo/Routes.lean`, and `Main.lean` fresh (current state, not the old
      plan's snapshot of them) and enumerate every function that reads a `Todo.*Url`
      constant/`Todo.*Pattern` constant.
- [ ] Add a parameter for the generated `Urls` type to every one of those functions (name it
      `urls`, threaded the same way `db` already is), replacing each `Todo.*Url` reference with
      `urls.<field>`.
- [ ] Rewrite every handler in `Main.lean` (`pageHandler`, `addHandler`, `editHandler`,
      `saveHandler`, `toggleHandler`, `deleteHandler`, `toggleAllHandler`,
      `clearCompletedHandler`) to take `(ctx : SQLite) (urls : AppUrls)` as its first two curried
      arguments (order per §5), instead of just `db`.
- [ ] Replace `Main.lean`'s `routes`/`def routes (db : SQLite) := [...]` list with one
      `application app : SQLite where <tree>` block using this app's real patterns (the tree in
      §1/§3's worked example, adjusted to match whatever this app's *current* patterns actually are
      — check `Todo/Routes.lean` for the current literal strings, e.g. confirm whether it's
      `/todos/completed` or `/todos/clear-completed` before transcribing the tree; don't trust this
      doc's example strings over the actual source).
- [ ] Rewire `main` to `serve addr (app.handler db) >>= waitShutdown` (§1) instead of `routes db |>
      toHandler`.
- [ ] Delete `Todo/Routes.lean`'s hand-written `*Pattern`/`*Url` constants once nothing references
      them.
- [ ] Update every `TodoTests/Views.lean` call site that currently calls a view function without a
      `urls` argument — pass `app.urls` (or a local equivalent built the same way, if `Main` isn't
      importable from `TodoTests` — check the current import graph before assuming either way).
- [ ] `lean_build` (imports changed), then `lake build`, then `lake test` (or whatever this repo's
      current test-running command is — check `lakefile.toml`/README rather than assuming `lake
      test` still applies) — all three must pass before considering this phase done.

### Phase 4 — cleanup

- [ ] Once `Todo/Routes.lean`'s named constants are gone and nothing calls `route`/`Route.get`/
      `Route.post`/`Route.put`/`Route.delete`/`routeUrl` with anything but a string *literal*
      anymore, re-open whether to harden those five functions into literal-only macros (the
      `parsePattern!`-retirement idea `docs/reverse-routing-macro-plan.md` §5 scoped and deferred
      for exactly this sequencing reason). Not required for this feature to ship; worth a
      deliberate yes/no rather than silently doing or skipping it.
- [ ] Re-read `Routing.lean`'s module docstring (the "How to add a route" section in particular)
      and update it to describe `application` as the primary way to build a route table, with
      `route`/`Route.get`/etc. demoted to "what `application` expands to" rather than the top-level
      recommended API.
