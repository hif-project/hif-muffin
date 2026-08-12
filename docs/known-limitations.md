# HIF toolchain: known limitations

A working statement of what `hif-frontend`'s Verilog parser and the rest of the HIF toolchain (`hif-core`, `hif-frontend`, `hif-backend`) actually support today, kept honest by listing only things that have been tested, not assumed. This is the "can I rely on X" reference for anyone building on top of `hif-muffin`.

## Confirmed working (behavioral RTL)

Verified via real fixtures through the full `verilog2hif -> HIF -> hif2verilog` round trip, byte-level checked in several cases:

- `assign` statements with expressions (`&`, `|`, `^`, `~`, ternary, slices, concatenation, replication).
- `always` blocks, sensitivity lists, `if`/`else`, `case`.
- Module ports, plain module instantiation (one module instance inside another), multi-bit buses.
- Multiple files in one `verilog2hif` invocation, in either order, without state leaking between them.
- Escaped identifiers and the 8 basic gate primitives (`and`/`nand`/`or`/`nor`/`xor`/`xnor`/`buf`/`not`), validated against real EPFL and logikbench ISCAS85 files, not just hand-written repros: 0 crashes across the EPFL arithmetic/control corpus (20 files) and the logikbench ISCAS85 corpus (11 files).

## Known unresolved limitations

- **No `Int`-`Int` typing rule under Verilog semantics.** `hif-core`'s `VerilogAnalysis` has no `map(Int*, Int*)` overload, so any binary expression combining two `Int`-typed operands under Verilog semantics fails to type. This needs dedicated Verilog arithmetic-semantics design (sign promotion, span/precision rules), not a mechanical patch. Coverage of other operand-type pairs hasn't been systematically audited — treat "some Verilog expression fails to type" as a plausible bug class, not a one-off.
- **`~&` (reduction-NAND) is unsupported.** A standard Verilog reduction operator, not yet implemented in `hif-frontend`'s grammar. Other reduction operators (`&`, `|`, `~|`, `^`, `~^`) haven't been individually verified for parity — don't assume they all work just because one plain `&` reduction happened to appear in a passing fixture.
- **A class of declaration-resolution failures during post-parsing refinement.** Several plain behavioral-RTL constructs (FSMs, gray-to-binary converters, clock gating, latches, muxes, one-hot encoders, shift registers) hit an assertion in declaration resolution; not yet root-caused as one shared issue or several distinct ones.
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

- **Verilog semantics' type coverage is not exhaustively audited.** The `Int`-`Int` gap above was found by investigating one specific failure; other operand-type combinations haven't been systematically checked against `VHDLAnalysis`/`HIFAnalysis` for parity.
- **Source position precision is only as good as what each grammar production's semantic action captures.** Some translation-synthesized nodes (e.g. a `Cast` synthesized from a slice-at-bit-0) never get position info set at all.
- **`BList<T>`/`ListElement<T>`'s type-erasure is not vptr-sanitizer-clean by design** — see above. This is a property of a foundational, heavily-used data structure, not something to route around per call site.
