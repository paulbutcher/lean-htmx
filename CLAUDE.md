# CLAUDE.md

Project-specific guidance for Claude Code when working in this repo.

## Verifying Lean changes

- After editing a `.lean` file, verify it with `mcp__lean-lsp__lean_diagnostic_messages`
  (or other lean-lsp-mcp tools — e.g. `lean_goal`/`lean_multi_attempt` for
  interactive proof/termination work).
- Ignore the editor's `<ide_diagnostics>` hook output.
- Before considering a task complete, run `lake build` from the repo root
  as the final ground truth.
- If a change adds or removes an `import`, use `mcp__lean-lsp__lean_build`
  instead of (or in addition to) plain `lake build`.
