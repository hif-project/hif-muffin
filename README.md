# HIF Muffin

Automatic fault injection for RTL designs, built on [HIF](https://github.com/hif-project/hif-core).

`muffin` takes a HIF description (typically produced from Verilog by
[hif-frontend](https://github.com/hif-project/hif-frontend)), discovers
injectable locations, enumerates stuck-at (SA0/SA1) faults, and instruments
the design so faults can be activated at runtime through a single control
port. The instrumented HIF can be regenerated back to Verilog by
[hif-backend](https://github.com/hif-project/hif-backend).

```
Verilog -> hif-frontend -> HIF -> muffin -> instrumented HIF -> hif-backend -> instrumented Verilog
```

Part of the HIF project. See https://github.com/hif-project for the
complete list of repositories and tools.

![CI](https://github.com/hif-project/hif-muffin/actions/workflows/ci.yml/badge.svg?branch=develop)

Cross-repository integration/regression testing for the whole HIF ecosystem (this repo included) lives in [hif-regression](https://github.com/hif-project/hif-regression), not here — this repo owns only its own CI and product tests.

## Usage

Two mutually exclusive modes:

```sh
muffin input.hif --list-faults faults.json           # discovery + enumeration only, writes JSON
muffin input.hif --instrument -o instrumented.hif.xml # full pipeline, writes instrumented HIF
```

`muffinMutPort == 0` is golden (no fault active); `muffinMutPort == N` activates fault ID `N`. A single instrumented design carries every fault simultaneously — build once, drive the port per simulation run.

Changing `muffinMutPort` is enough on its own: instrumented combinational processes become sensitive to it, so a fault activates and clears without needing to re-apply stimulus. In a clocked process the fault takes effect on the next active clock edge, as any other change to that process's inputs would.

Each injectable location yields one SA0 and one SA1 fault **per bit**, so an `N`-bit target contributes `2N` faults, and activating one of them forces that single bit while leaving the rest of the vector as the design computed it. This holds whether the target's width is a literal (`reg [3:0]`) or an expression over a module parameter (`reg [WIDTH-1:0]`). A target whose width cannot be resolved is reported as an error rather than guessed at — see `docs/known-limitations.md`.

## Hierarchy and the activation port

Muffin adds `muffinMutPort` to every RTL view and binds it, at every instance, to the same-named port of the instantiating module — so one value driven at the top reaches every level. **Whether your design still has a hierarchy when Muffin sees it depends on the frontend, not on Muffin:**

| Input | Hierarchy reaching Muffin | Notes |
|---|---|---|
| `verilog2hif` (default) | inlined | Instances are flattened into the parent; Muffin instruments one flat view and reports `0 instance(s)`. This is correct behavior, not a failure. |
| `verilog2hif -s` / `--structure` | preserved | Instances survive, Muffin wires the port through each one. |
| `vhdl2hif` | preserved | Hierarchy is kept by default; no flag needed. |
| Hand-written / tool-generated HIF | as authored | Whatever the file contains. |

The Verilog frontend's flattening is *partial and conditional* — it targets output ports written by blocking/continuous assignments — and is skipped entirely under `-s`. Note `-s`'s own warning: it preserves structure "even when this could lead to non-equivalent translation".

Two consequences worth knowing before running a hierarchical campaign:

- **Faults are per design unit, not per instance.** A module instantiated twice has one set of fault ids shared by both instances, so activating one fires it in *every* instance of that module simultaneously. Instrumenting a specific instance is not expressible today.
- **The `-s` path is not currently simulatable end to end.** `hif2verilog` regenerates internal connection nets as `reg`, which Verilog forbids as the target of an instance's output port. This reproduces with Muffin entirely absent from the pipeline — it is an upstream backend limitation, not an instrumentation defect. See [docs/known-limitations.md](docs/known-limitations.md).

## Examples

- [examples/and2](examples/and2/README.md) — start here. A step-by-step tutorial that takes a three-line AND gate through the full pipeline and simulates it with Icarus Verilog, so you can watch stuck-at-0 and stuck-at-1 change the output against the golden circuit.

## Requirements

- Linux (only supported/tested platform)
- CMake ≥ 3.1, a C++ compiler
- A build of [hif-core](https://github.com/hif-project/hif-core), found via `cmake/FindHIF.cmake` (same discovery mechanism used by hif-frontend and hif-backend)
- To run the product tests: builds of [hif-frontend](https://github.com/hif-project/hif-frontend) (for `verilog2hif`) and [hif-backend](https://github.com/hif-project/hif-backend) (for `hif2verilog`) as sibling directories, plus Icarus Verilog (`iverilog`) for the two simulated tests — see "Running tests" below

## Building

```sh
mkdir build && cd build
cmake ..
make
```

If `hif-core` is not installed system-wide, point CMake at it:

```sh
cmake -DHIF_DIR=/path/to/hif-core ..
```

## Running tests

```sh
ctest --test-dir build --output-on-failure
```

The tests here drive the real `verilog2hif`/`hif2verilog` tools end to end, not just HIF-level checks:

| Test | Covers |
|---|---|
| `and2_round_trip` | the full `verilog2hif` -> `--list-faults` -> `--instrument` -> `hif2verilog` pipeline |
| `fault_enumeration_*` | fault counts and per-bit metadata for scalar, fixed-width and parameterized targets |
| `param_reg_behavioral` | a fault on bit N forces bit N and leaves the other bits intact (simulated) |
| `mutport_sensitivity` | changing `muffinMutPort` alone activates and clears a fault, and clocked processes are untouched (simulated) |
| `hierarchical_wiring` | the activation port is threaded through real instances under `verilog2hif -s` |
| `hierarchical_behavioral` | a fault in a child module activates through both of its instances, and the parent's own fault does not (simulated) |

They look for `verilog2hif`/`hif2verilog` on `PATH` and, since this repo is normally checked out alongside its siblings, in `../hif-frontend/build`/`../hif-backend/build` too. The three simulated tests additionally need `iverilog`. Anything not found means the affected tests are silently skipped rather than failed — check the CMake configure output for "not found" lines if you expect one to have run.

## Known limitations

See [docs/known-limitations.md](docs/known-limitations.md) for what the toolchain does and doesn't support today.

## License

BSD 2-Clause. See [LICENSE.md](LICENSE.md).
