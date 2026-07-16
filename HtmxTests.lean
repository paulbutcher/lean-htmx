import Tests.Attrs
import Tests.Tags

/-!
# `Tests`: tests for the `Htmx` library

Build-time tests (`#guard`) for `Htmx.Attrs` (`Tests/Attrs.lean`) and
`Htmx.Tags` (`Tests/Tags.lean`). Not a default target -- run via `lake test`,
which for a library target simply builds it (see the package's `testDriver`
in `lakefile.toml`), triggering every `#guard` below as a build-breaking
error on failure.
-/
