# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

- Added `hierarchical_behavioral`, which proves by simulation what `hierarchical_wiring` could only check structurally (issue #10): the `verilog2hif -s` → `--instrument` → `hif2verilog` pipeline now produces a hierarchy that compiles, and its golden behaviour and four selected faults are checked against exact oracles. The oracles encode the per-design-unit fault model — selecting a fault on the child's `sum` forces it in both instances — so a future per-instance model shows up here. Requires [hif-backend#26](https://github.com/hif-project/hif-backend/issues/26); `.ci/pinned-refs.env` moves `HIF_BACKEND_REF` past v1.1.0 to pick it up. The VHDL half of that limitation ([hif-backend#27](https://github.com/hif-project/hif-backend/issues/27)) is still open and `docs/known-limitations.md` now records only that half.

- Instrumenting a purely level-sensitive process now adds `muffinMutPort` to its sensitivity list (issue #16). Muffin introduced a read of the activation port without registering it, so on a settled combinational design changing `muffinMutPort` alone did not re-evaluate the logic and a fault only appeared once some unrelated input happened to toggle. Edge-sensitive processes are deliberately left alone — a register must not update between clock edges because the activation port moved — as are processes with an empty sensitivity list (`always @*`), where adding an entry would restrict sensitivity rather than extend it.

- Fixed fault enumeration and injection for signals whose width is a parameter expression (issue #9). Such a signal resolved to width 1, so a `WIDTH`-bit target yielded 2 faults instead of `2 * WIDTH`, and the injector's single-bit path replaced the *entire* target with a literal instead of forcing one bit. Span bounds are now resolved through the design unit's template parameters, and the injector takes its width from the enumerated fault rather than recomputing it.
- A location whose width cannot be resolved is now a reported error naming the assignment and its source position, instead of being silently treated as 1 bit wide.
- Fixed the injected bit-mask for bit indices >= 63, which previously overflowed a signed 64-bit shift and made the masks for the top bits of a wide vector alias those of its bottom bits. Masks are now sized literals of exactly the location's width.
- Added product tests covering fixed-width scalar, fixed-width multi-bit and parameterized multi-bit enumeration, plus a behavioral Icarus Verilog test proving a fault on bit N forces bit N and leaves the other bits intact. The behavioral test asserts a plain `verilog2hif` -> `hif2verilog` round trip of the fixture first, so an upstream defect is reported as one rather than as a fault-injection failure, and dumps the generated Verilog when the simulation fails.
- Bumped `.ci/pinned-refs.env` to the v1.1.0 release commits (#15). The previous pins were set when CI was added and never bumped, leaving CI validating against a pre-release toolchain whose backend drops a module's parameter declaration on a plain round trip, regenerating `reg [WIDTH-1:0]` as `reg [18446744073709551615:0]`.
- Documented and pinned hierarchical activation-port wiring (issue #10). `MutPortInjector::visitInstance` is not dead code: it is reachable from `verilog2hif -s`/`--structure`, from `vhdl2hif` (which preserves hierarchy by default), and from hand-written HIF — only the *default* Verilog flow inlines instances before Muffin sees them. Added the `hierarchical_wiring` product test covering both the flattened and the structure-preserving flow, and a README section plus two `docs/known-limitations.md` entries recording the per-design-unit (not per-instance) fault model and the upstream round-trip gap that stops the `-s` path short of simulation.

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
