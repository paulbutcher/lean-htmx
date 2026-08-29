# Changelog

## [0.6.1] - 2026-08-29

* The build now treats warnings as errors
* Documentation tightened

## [0.6.0] - 2026-08-20

Switch to module system

## [0.5.0] - 2026-08-15

Tests moved to a `test` subproject, so downstream consumers no longer resolve test-only tooling.

## [0.4.0] - 2026-08-07

List, table, and `select` wrappers take `Html`'s content-model categories, so invalid children are a type error.

## [0.3.0] - 2026-08-06

Each wrapper now takes a single merged `attrs` record, giving it exactly the signature of the `Html` tag it wraps.

## [0.2.1] - 2026-08-06

Per-element attribute records (`OlAttrs`, `FormAttrs`, `ImgAttrs`, ...) are now reachable through the wrappers.

## [0.2.0] - 2026-08-06

Add support for `hx-on`.

## [0.1.1] - 2026-07-17

Documentation and packaging fixes.

## [0.1.0] - 2026-07-16

Initial release.
