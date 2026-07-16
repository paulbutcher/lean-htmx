import HtmxTests.Attrs
import HtmxTests.Tags

/-!
# `HtmxTests`: tests for the `Htmx` library

Build-time tests (`#guard`) for `Htmx.Attrs` (`HtmxTests/Attrs.lean`) and
`Htmx.Tags` (`HtmxTests/Tags.lean`). Not a default target -- run via `lake test`,
which for a library target simply builds it (see the package's `testDriver`
in `lakefile.toml`), triggering every `#guard` below as a build-breaking
error on failure.
-/
