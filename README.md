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

Status: early work in progress. No stable CLI or fault model yet.

## Requirements

- A build of [hif-core](https://github.com/esd-univr/hif-core), found via
  `cmake/FindHIF.cmake` (same discovery mechanism used by hif-frontend and
  hif-backend).
- CMake >= 3.1, a C++ compiler.

## Building

```bash
mkdir build && cd build
cmake ..
make
```

If `hif-core` is not installed system-wide, point CMake at it:

```bash
cmake -DHIF_DIR=/path/to/hif-core ..
```

## License

BSD 2-Clause. See [LICENSE.md](LICENSE.md).
