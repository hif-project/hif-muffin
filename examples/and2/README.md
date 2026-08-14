# Example: stuck-at faults on a two-input AND

This is the "does this thing actually work?" tutorial for Muffin. It starts
from three lines of Verilog and ends with a simulation where you can watch a
stuck-at fault change the circuit's output, side by side with the fault-free
behaviour.

Everything here is deliberately tiny. The point is not the design — it is
seeing the whole pipeline, once, end to end, with nothing hidden.

```
and2.v
   |
   | verilog2hif
   v
and2.hif.xml
   |
   | muffin --list-faults
   +----------------------> faults.json
   |
   | muffin --instrument
   v
and2_instrumented.hif.xml
   |
   | hif2verilog
   v
generated/and2.v          (same design + a muffinMutPort input)
   |
   | iverilog + vvp   (with tb.v)
   v
golden / SA0 / SA1 behaviour
```

There is a `run.sh` that does all of this in one shot, but **run the steps by
hand first**. The script is a shortcut for the second time, not the tutorial.

---

## Prerequisites

On Ubuntu/Debian:

```sh
sudo apt update
sudo apt install build-essential cmake git flex bison libpoco-dev iverilog
```

You need four executables on your `PATH`:

| Tool          | Comes from      | Does what                              |
| ------------- | --------------- | -------------------------------------- |
| `verilog2hif` | `hif-frontend`  | Verilog -> HIF                         |
| `muffin`      | `hif-muffin`    | fault enumeration + instrumentation    |
| `hif2verilog` | `hif-backend`   | HIF -> Verilog                         |
| `iverilog`    | Icarus Verilog  | simulates the result                   |

### If you already have the HIF toolchain built

Add the build directories to your `PATH`:

```sh
export PATH=/path/to/hif-frontend/build:$PATH
export PATH=/path/to/hif-backend/build:$PATH
export PATH=/path/to/hif-muffin/build:$PATH
```

### Starting from scratch

The four repositories locate each other as siblings, so check them all out
into the same parent directory, at the `v1.1.0` tag:

```sh
mkdir hif && cd hif
for repo in hif-core hif-frontend hif-backend hif-muffin; do
    git clone --branch v1.1.0 https://github.com/hif-project/$repo.git
done
```

Build them in this order — `hif-core` first, since the other three link
against it (they find `../hif-core` automatically; no `make install` needed):

```sh
for repo in hif-core hif-frontend hif-backend hif-muffin; do
    cmake -S $repo -B $repo/build -DCMAKE_BUILD_TYPE=Release
    make -C $repo/build -j"$(nproc)"
done
```

Then put the three tool build directories on your `PATH`:

```sh
export PATH=$PWD/hif-frontend/build:$PWD/hif-backend/build:$PWD/hif-muffin/build:$PATH
```

### Check

```sh
verilog2hif --version
hif2verilog --version
muffin --version
iverilog -V | head -1
```

(The HIF tools all report `version 1.0.0` — that is the internal tool version,
not the `v1.1.0` repository release tag. Seeing `1.0.0` here is expected.)

If a tool starts but complains about `libhif.so`, it cannot find the shared
library that `hif-core` built; add it to the loader path:

```sh
export LD_LIBRARY_PATH=/path/to/hif-core/build:$LD_LIBRARY_PATH
```

---

## The design

`and2.v`, in full:

```verilog
module and2(input a, input b, output y);
  assign y = a & b;
endmodule
```

One output, one gate. Two possible stuck-at faults on `y`: stuck-at-0 and
stuck-at-1. That is the entire fault universe for this design, which is
exactly why it is a good first example — you can check the tool's answer in
your head.

Work from this directory, and keep every generated artifact in `work/`:

```sh
cd hif-muffin/examples/and2
mkdir -p work
```

---

## Step 1 — Verilog to HIF

Muffin does not read Verilog. It reads HIF, the intermediate format the whole
toolchain is built around, so the first step is a translation:

```sh
verilog2hif -o work/and2 and2.v
```

This writes `work/and2.hif.xml`. It is XML; you do not need to read it, but
feel free to look — it is the design as a tree, with source positions
preserved. Those positions are what lets Muffin tell you later that the fault
it found lives at `and2.v` line 2.

## Step 2 — Ask Muffin what it can break

```sh
muffin work/and2.hif.xml --list-faults work/faults.json
```

Muffin prints what it found:

```
[MUFFIN] 09:41:12 - INFO: Found 1 injectable location(s).
[MUFFIN] 09:41:12 - INFO: Enumerated 2 stuck-at fault(s).
[MUFFIN] 09:41:12 - INFO: Wrote fault list to work/faults.json.
```

One *location* (the expression driving `y`), two *faults* (that location stuck
at 0, and stuck at 1). Look at the list:

```sh
cat work/faults.json
```

```json
{
    "schema_version": 2,
    "design": "and2",
    "golden_fault_id": 0,
    "faults": [
        {
            "id": 1,
            "type": "stuck-at-0",
            "bit": 0,
            "width": 1,
            "signal": "y",
            "source": "and2.v",
            "line": 2
        },
        {
            "id": 2,
            "type": "stuck-at-1",
            "bit": 0,
            "width": 1,
            "signal": "y",
            "source": "and2.v",
            "line": 2
        }
    ]
}
```

**Stop here for a second, because this is the file that ties the whole flow
together.**

| Field              | Meaning                                                                                 |
| ------------------ | --------------------------------------------------------------------------------------- |
| `id`               | The fault's identifier. **This is the number you will drive on `muffinMutPort`** to activate it. |
| `golden_fault_id`  | The reserved ID meaning "no fault active" — always `0`.                                  |
| `type`             | `stuck-at-0` or `stuck-at-1`.                                                            |
| `signal`           | Which signal the fault sits on. Here, `y`.                                               |
| `bit` / `width`    | Which bit of that signal, and how wide the signal is. `y` is 1 bit, so `bit` is `0` and `width` is `1`. On an 8-bit bus you would get eight bit positions, each with its own SA0 and SA1 fault. |
| `source` / `line`  | Where in *your original Verilog* the faulted signal was written — `and2.v`, line 2. This survives the whole Verilog -> HIF -> Verilog trip. |

So Muffin found exactly the two faults you would have written down by hand,
and it named them 1 and 2. Remember those numbers.

## Step 3 — Instrument the design

Same input file, different mode:

```sh
muffin work/and2.hif.xml --instrument -o work/and2_instrumented.hif.xml
```

```
[MUFFIN] 09:41:18 - INFO: Found 1 injectable location(s).
[MUFFIN] 09:41:18 - INFO: Enumerated 2 stuck-at fault(s).
[MUFFIN] 09:41:18 - INFO: Wired activation port through 1 view(s) and 0 instance(s).
[MUFFIN] 09:41:18 - INFO: Instrumented 1 location(s).
```

"Wired activation port" is the interesting line: Muffin added a new input port
to the module and threaded it down through the hierarchy (trivially, here —
there is only one module and no instances).

## Step 4 — Back to Verilog

`hif2verilog` emits one file per module, so `-D` gives it a directory to write
into rather than a file name. It also drops a couple of
`HIF2VERILOG_01_Final_tree.hif*` debug dumps in the *current* directory, so run
it from inside `work/` to keep them out of the source tree:

```sh
( cd work && hif2verilog and2_instrumented.hif.xml -D generated )
```

## Step 5 — Look at what changed

```sh
cat work/generated/and2.v
```

```verilog
// @file generated/and2.v
// @brief This file was generated by hif2verilog.
// @details
// Generate with HIF version 1.0.0.

module and2(
    input wire a,
    input wire b,
    output reg y,
    input wire [31:0] muffinMutPort
);
    always @( a, b ) begin
        y <= ((muffinMutPort == 1) ? (0) : (muffinMutPort == 2) ? (1) : (a & b)
            );

    end
endmodule
```

Or just the part that matters:

```sh
grep -n "muffinMutPort" work/generated/and2.v
```

This is the whole idea of Muffin in one expression:

- `muffinMutPort == 1` — fault 1 from `faults.json` — forces `y` to `0`. Stuck-at-0.
- `muffinMutPort == 2` — fault 2 — forces `y` to `1`. Stuck-at-1.
- anything else, including `0` — the original `a & b`.

Note what this *is not*: three different netlists. It is one design carrying
every fault at once, selected at runtime by an ordinary input port. A fault
campaign over N faults is one compilation and N simulations, not N
compilations.

Two cosmetic changes worth pointing out so they don't surprise you: `y` became
an `output reg` driven from an `always` block rather than a continuous
`assign`, and `muffinMutPort` is 32 bits wide (fault IDs are integers, so the
port is sized for a realistically large campaign, not for this design's two
faults).

## Step 6 — Simulate

`tb.v` in this directory instantiates the *generated* module — not the `and2.v`
you started from, which has no `muffinMutPort`. It computes the golden result
itself as `wire golden_y = a & b;`, then drives `muffinMutPort` to 0, 1 and 2
in turn and walks all four input vectors under each:

```sh
iverilog -o work/sim work/generated/and2.v tb.v
vvp work/sim
```

```
=== Golden: muffinMutPort = 0 (no fault active) ===
  a=0 b=0  golden=0  dut=0   PASS
  a=0 b=1  golden=0  dut=0   PASS
  a=1 b=0  golden=0  dut=0   PASS
  a=1 b=1  golden=1  dut=1   PASS

=== Fault 1: y stuck-at-0 (muffinMutPort = 1) ===
  a=0 b=0  golden=0  dut=0   PASS
  a=0 b=1  golden=0  dut=0   PASS
  a=1 b=0  golden=0  dut=0   PASS
  a=1 b=1  golden=1  dut=0   PASS   <-- fault detected

=== Fault 2: y stuck-at-1 (muffinMutPort = 2) ===
  a=0 b=0  golden=0  dut=1   PASS   <-- fault detected
  a=0 b=1  golden=0  dut=1   PASS   <-- fault detected
  a=1 b=0  golden=0  dut=1   PASS   <-- fault detected
  a=1 b=1  golden=1  dut=1   PASS

RESULT: PASS - golden matches a & b, fault 1 behaves as y stuck-at-0, fault 2 as y stuck-at-1.
```

`PASS`/`FAIL` is the testbench's own verdict on each vector — did the DUT do
what this fault is *supposed* to do. `<-- fault detected` is the separate,
more interesting question: did this input vector make the fault *visible* at
the output.

The testbench fails (prints `RESULT: FAIL` and exits non-zero) if
`muffinMutPort = 0` ever differs from `a & b`, if fault 1 is not a clean `y`
stuck-at-0, or if fault 2 is not a clean `y` stuck-at-1.

## Step 7 — Read the detection pattern

This is the part worth staring at, because it is fault simulation in
miniature.

**Fault 1 (`y` stuck-at-0) is detected by exactly one vector: `a=1, b=1`.**
To notice that a signal is stuck at 0, you have to make the good circuit drive
it to 1. `a & b` is 1 for one input combination out of four, so exactly one of
the four vectors can expose this fault. The other three produce `0` either
way, and the fault sits there undetected.

**Fault 2 (`y` stuck-at-1) is detected by the other three vectors.** Mirror
image: you need the good circuit to drive `y` to 0, and `a & b` is 0 three
times out of four.

Together, the four vectors detect both faults — this design's exhaustive test
set has 100% stuck-at fault coverage, which for a single AND gate is not a
surprise. Scale the design up and this stops being obvious, and choosing
vectors that maximise detected faults per simulation becomes the entire game.
That is what the instrumented design is *for*.

---

## The shortcut

Once you have done it by hand:

```sh
./run.sh
```

It runs exactly the commands above into a clean `work/`, echoes `faults.json`
and the generated Verilog along the way, and ends with:

```
SUCCESS: golden, stuck-at-0 and stuck-at-1 all behaved as expected.
```

Afterwards `work/` contains:

```
work/
├── and2.hif.xml                        (step 1)
├── faults.json                         (step 2)
├── and2_instrumented.hif.xml           (step 3)
├── generated/
│   └── and2.v                          (step 4)
├── HIF2VERILOG_01_Final_tree.hif       (step 4, hif2verilog debug dumps)
├── HIF2VERILOG_01_Final_tree.hif.xml
├── sim                                 (step 6, iverilog output)
└── sim.log
```

`work/` is generated and git-ignored; delete it freely.

---

## Notes and gotchas

- **`muffinMutPort` is not in the `always` block's sensitivity list.** Changing
  it alone does not re-evaluate `y`. `tb.v` handles this by toggling an input
  after switching faults (see the `select_fault` task); if you write your own
  testbench, apply your input vectors *after* selecting the fault, not before.
- **Fault IDs come from `faults.json`, not from convention.** They happen to be
  1 and 2 here. Do not hard-code them for a real design — read the JSON.
- **`muffinMutPort` is an ordinary input.** In a hierarchical design Muffin
  threads it through every instance, so you drive it once, at the top.
- For what the toolchain does and does not support, see
  [docs/known-limitations.md](../../docs/known-limitations.md).
