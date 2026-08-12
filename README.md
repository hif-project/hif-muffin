# HIF Muffin

Automatic fault injection for RTL designs, built on [HIF](https://github.com/esd-univr/hif-core).

`muffin` takes a HIF description (typically produced from Verilog by
[hif-frontend](https://github.com/esd-univr/hif-frontend)), discovers
injectable locations, enumerates stuck-at (SA0/SA1) faults, and instruments
the design so faults can be activated at runtime through a single control
port. The instrumented HIF can be regenerated back to Verilog by
[hif-backend](https://github.com/esd-univr/hif-backend).

```
Verilog -> hif-frontend -> HIF -> muffin -> instrumented HIF -> hif-backend -> instrumented Verilog
```

Part of the HIF toolchain for HDL-independent-format compilation:
- [hif-core](https://github.com/esd-univr/hif-core) — shared AST/IR library
- [hif-frontend](https://github.com/esd-univr/hif-frontend) — Verilog/VHDL → HIF
- [hif-backend](https://github.com/esd-univr/hif-backend) — HIF → Verilog/VHDL(/SystemC)
- **hif-muffin** (this repo) — RTL fault injection, built on the above

![CI](https://github.com/esd-univr/hif-muffin/actions/workflows/ci.yml/badge.svg?branch=develop)
![Nightly Integration](https://github.com/esd-univr/hif-muffin/actions/workflows/nightly-integration.yml/badge.svg?branch=develop)

## Usage

Two mutually exclusive modes:

```sh
muffin input.hif --list-faults faults.json           # discovery + enumeration only, writes JSON
muffin input.hif --instrument -o instrumented.hif.xml # full pipeline, writes instrumented HIF
```

`muffinMutPort == 0` is golden (no fault active); `muffinMutPort == N` activates fault ID `N`. A single instrumented design carries every fault simultaneously — build once, drive the port per simulation run.

## Requirements

- Linux (only supported/tested platform)
- CMake ≥ 3.1, a C++ compiler
- A build of [hif-core](https://github.com/esd-univr/hif-core), found via `cmake/FindHIF.cmake` (same discovery mechanism used by hif-frontend and hif-backend)
- To actually run the `and2_round_trip` test: builds of [hif-frontend](https://github.com/esd-univr/hif-frontend) (for `verilog2hif`) and [hif-backend](https://github.com/esd-univr/hif-backend) (for `hif2verilog`) as sibling directories too — see "Running tests" below

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

The one CTest here, `and2_round_trip`, exercises the full `verilog2hif -> muffin --list-faults -> muffin --instrument -> hif2verilog` pipeline through the real tools — not just HIF-level checks. It looks for `verilog2hif`/`hif2verilog` on `PATH` and, since this repo is normally checked out alongside its siblings, in `../hif-frontend/build`/`../hif-backend/build` too. If neither sibling is built, the test is silently skipped rather than failing — check the CMake configure output for "verilog2hif/hif2verilog not found" if you expect it to have run.

## Known limitations

See [docs/known-limitations.md](docs/known-limitations.md) for what the toolchain does and doesn't support today.

## License

BSD 2-Clause. See [LICENSE.md](LICENSE.md).
