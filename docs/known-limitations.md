# HIF toolchain: known limitations

A working statement of what `hif-frontend`'s Verilog parser and the rest of the HIF toolchain (`hif-core`, `hif-frontend`, `hif-backend`) actually support today, kept honest by listing only things that have been tested, not assumed. This is the "can I rely on X" reference for anyone building on top of `hif-muffin`.

## Confirmed working (behavioral RTL)

Verified via real fixtures through the full `verilog2hif -> HIF -> hif2verilog` round trip, byte-level checked in several cases:

- `assign` statements with expressions (`&`, `|`, `^`, `~`, ternary, slices, concatenation, replication).
- `always` blocks, sensitivity lists, `if`/`else`, `case`.
- Module ports, plain module instantiation (one module instance inside another), multi-bit buses.
- Multiple files in one `verilog2hif` invocation, in either order, without state leaking between them.
- Escaped identifiers and the 8 basic gate primitives (`and`/`nand`/`or`/`nor`/`xor`/`xnor`/`buf`/`not`), validated against real EPFL and logikbench ISCAS85 files, not just hand-written repros: 0 crashes across the EPFL arithmetic/control corpus (20 files) and the logikbench ISCAS85 corpus (11 files).
- Binary expressions combining two `Int`-typed operands under Verilog semantics (`VerilogAnalysis::map(Int*, Int*)`, fixed in hif-core v1.1.0), the `~&` (reduction-NAND) operator (fixed in hif-frontend v1.1.0), and `$clog2` used standalone in a port range (fixed in hif-core/hif-frontend v1.1.0) — confirmed against the logikbench `basic` fixtures that previously crashed on each (`gray2bin`/`muxhot`/`shiftreg`, `bnand`, `fsm`/`onehot`, respectively).

## Known unresolved limitations

- **A fault location's bit-width must be statically resolvable.** Muffin resolves span bounds that are expressions over a design unit's template parameters by substituting the parameter's elaborated/default value, so `reg [WIDTH-1:0]` enumerates as `WIDTH` bits (fixed in this repo, issue #9). A width that still cannot be folded to a constant — a parameter with no default that survives to Muffin, or a bound hitting the `$clog2`-plus-arithmetic gap below — is reported as an error naming the offending assignment and its source position. Muffin deliberately does not guess a width: a wrong one silently under-enumerates faults *and* makes the injector overwrite the whole target instead of one bit, producing fault records that misdescribe the design.
- **`mux.v`-class constant-folding gap: `$clog2` combined with further arithmetic in a range bound.** `$clog2` is registered in Verilog's standard library and works standalone in a port range (fixed in hif-core/hif-frontend v1.1.0), but the simplifier has no rule to numerically evaluate a `$clog2` call when it's combined with additional arithmetic in the same bound — this narrower case still fails, now in `simplifyExpression.cpp` rather than at registration.
- **Instrumenting a VHDL design has no behavioral coverage here.** The round-trip defects that used to make it impossible are fixed — `hif2vhdl` no longer writes a zero-byte file for a design unit ([hif-backend#27](https://github.com/hif-project/hif-backend/issues/27)) — but two things still stand in the way, neither of them an instrumentation defect:

  - no VHDL simulator is part of this repo's tests or CI, so a VHDL flow can be checked structurally but not by simulation;
  - routing a VHDL design to the Verilog simulation path instead does not work: `hif2verilog` drops a view's `GlobalAction`, which is where `vhdl2hif` puts concurrent signal assignments, so a VHDL-derived design regenerates as a module with correct ports and an empty body ([hif-backend#32](https://github.com/hif-project/hif-backend/issues/32), open).

  The Verilog path is fully covered. `verilog2hif -s` → `muffin --instrument` → `hif2verilog` regenerates a hierarchy that compiles and simulates, and the `hierarchical_behavioral` test checks golden behaviour and four faults against exact oracles. Until [hif-backend#26](https://github.com/hif-project/hif-backend/issues/26) was fixed the regenerated parent declared its instance-connected nets as `reg` while binding them to child instance *output* ports, which Verilog forbids, so Icarus rejected the design at elaboration. `.ci/pinned-refs.env` pins a backend commit carrying both fixes.
- **Fault injection is per design unit, not per instance.** A module instantiated N times shares one set of fault ids across all N instances, and they all receive the same `muffinMutPort` value, so a fault activates in every instance at once. Targeting one specific instance is not expressible today. Not a bug in the current model — a limit of it, and one that matters when interpreting coverage numbers on a hierarchical design.
- **`icg`/`latch`-class undeclared library cells.** Both instantiate an external library cell (`la_clkicgand`, `la_vlatq` from "lambdalib") with no declaration anywhere in the design. This isn't a declaration-resolution bug — there's nothing to resolve — but the tool's response is a hard assert crash rather than a clean, actionable error; fixing the crash-vs-clean-error question is a policy decision, not yet made.
- **`-fsanitize=vptr` is expected to fire against HIF's list machinery — it is not a sign of memory corruption.** `hif-core`'s `BList<T>`/`ListElement<T>` generic-list implementation uses a deliberate, documented type-erasure idiom (union/reinterpret_cast-punning across distinct per-`T` vtables) that UBSan's vptr check correctly flags at multiple call sites across all three upstream repos. No accompanying ASan findings; generated output is correct. Don't run `-fsanitize=vptr` against this toolchain expecting a clean result.
- **Debug-build performance on large designs.** A slow tree-simplification pass in `hif-frontend` causes large input files to run well past typical CI timeouts in Debug builds (observed on a majority of the larger files in both the EPFL and ISCAS85 corpora) — confirmed crash-free and progressing normally, not a hang. Whether a Release build resolves this hasn't been checked.

## Unsupported-but-valid Verilog (legal syntax, not a deliberate exclusion)

- **User-defined primitives** (`primitive`/`endprimitive` blocks). Confirmed failing.
- **Switch-level primitives**: `tran`/`rtran`/`tranif0`/`tranif1`, `pullup`/`pulldown`, `cmos`/`nmos`/`pmos`. The grammar has stub productions for these (the same pattern the 8 basic gates used before being implemented) that reject cleanly rather than crash.

## Intentionally unsupported (deliberate scope decision, not a gap)

- **Verilog-AMS.** Out of scope for this project's goals — no analog/mixed-signal use case.
- **SystemVerilog.** This toolchain targets classic Verilog (IEEE 1364) only.
- **Reentrant/thread-safe parsing.** `verilog2hif`/`vhdl2hif` are one-shot CLI processes with global Flex/Bison state; there's no intent to make them embeddable or multi-threaded. Confirmed not a live problem for the cases exercised (no cross-file leakage within one process, no cross-tool collision between `verilog2hif`/`vhdl2hif`), but not proven absent in general.

## Architectural notes

- **Verilog semantics' type coverage is not exhaustively audited.** The `Int`-`Int` gap fixed in v1.1.0 was found by investigating one specific failure; other operand-type combinations haven't been systematically checked against `VHDLAnalysis`/`HIFAnalysis` for parity.
- **Source position precision is only as good as what each grammar production's semantic action captures.** Some translation-synthesized nodes (e.g. a `Cast` synthesized from a slice-at-bit-0) never get position info set at all.
- **`BList<T>`/`ListElement<T>`'s type-erasure is not vptr-sanitizer-clean by design** — see above. This is a property of a foundational, heavily-used data structure, not something to route around per call site.
