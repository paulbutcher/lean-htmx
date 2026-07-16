import Tests.Escape
import Tests.Node
import Tests.Attrs
import Tests.Tags
import Tests.Document

/-!
# `Tests`: tests for the `Html` library

Build-time tests (`#guard`/`#guard_msgs`) for `Html.Escape` (`Tests/Escape.lean`),
`Html.Node` (`Tests/Node.lean`), `Html.Attrs` (`Tests/Attrs.lean`), `Html.Tags`
(`Tests/Tags.lean`), and `Html.Document` (`Tests/Document.lean`). Not a default
target -- run via `lake test`, which for a library target simply builds it (see
the package's `testDriver` in `lakefile.toml`), triggering every `#guard` below
as a build-breaking error on failure.
-/
