/-
Copyright (c) 2026 Paul Butcher. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/

import Lake
open Lake DSL

package htmx where
  version := v!"0.6.0"

require html from git "https://github.com/paulbutcher/lean-html" @ "v0.7.0"

@[default_target]
lean_lib Htmx

/-- The `test` subproject is deliberately not a dependency of this package, so that
downstream consumers don't inherit test-only tooling. Running it as a child process
keeps `lake test` working from the repo root regardless. -/
@[test_driver]
script tests do
  let child ← IO.Process.spawn { cmd := "lake", args := #["test"], cwd := __dir__ / "test" }
  child.wait
