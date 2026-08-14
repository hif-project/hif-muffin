# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

- Fixed fault enumeration and injection for signals whose width is a parameter expression (issue #9). Such a signal resolved to width 1, so a `WIDTH`-bit target yielded 2 faults instead of `2 * WIDTH`, and the injector's single-bit path replaced the *entire* target with a literal instead of forcing one bit. Span bounds are now resolved through the design unit's template parameters, and the injector takes its width from the enumerated fault rather than recomputing it.
- A location whose width cannot be resolved is now a reported error naming the assignment and its source position, instead of being silently treated as 1 bit wide.
- Fixed the injected bit-mask for bit indices >= 63, which previously overflowed a signed 64-bit shift and made the masks for the top bits of a wide vector alias those of its bottom bits. Masks are now sized literals of exactly the location's width.
- Added product tests covering fixed-width scalar, fixed-width multi-bit and parameterized multi-bit enumeration, plus a behavioral Icarus Verilog test proving a fault on bit N forces bit N and leaves the other bits intact.

## [1.1.0] - 2026-08-13

- Removed the ecosystem-wide nightly cross-repo integration workflow (`.github/workflows/nightly-integration.yml`). That responsibility now belongs to [hif-regression](https://github.com/hif-project/hif-regression), the ecosystem's dedicated integration/regression repository. This repo's own CI (`ci.yml`) and product tests (including the `and2_round_trip` end-to-end test) are unaffected.
- Restored the `line` field in `faults.json`, bumping its schema to v2.
- Migrated the project to the `hif-project` GitHub organization; updated internal references accordingly.
- Replaced the README's ecosystem-navigation list with a link to the organization profile.
- Updated `docs/known-limitations.md`: the `Int`-`Int` typing gap, `~&` operator, and 4 of 7 declaration-resolution failures (`fsm`/`gray2bin`/`onehot`/`shiftreg`) are now fixed upstream; narrowed the remaining open items to the `mux` constant-folding gap and the `icg`/`latch` undeclared-library-cell cases.

## [1.0.0] - 2026-08-12

Initial coordinated release of the HIF toolchain baseline (hif-core, hif-frontend, hif-backend, hif-muffin, all tagged v1.0.0).

- Working `--list-faults`/`--instrument` fault-injection pipeline, verified end-to-end through real `verilog2hif`/`hif2verilog` round trips.
- Added CI (none existed before) and a nightly cross-repo integration workflow that rebuilds all four repos at floating `develop` HEAD and runs each one's test suite.
- Published `docs/known-limitations.md` as the toolchain's compatibility reference.
