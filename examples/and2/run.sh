#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Convenience wrapper around the pipeline documented in README.md.
#
# This script runs exactly the commands the README walks through, one after the
# other, into a clean work/ directory. It is a shortcut, not the tutorial: read
# README.md first and run the steps by hand at least once.
# -----------------------------------------------------------------------------

set -euo pipefail

cd "$(dirname "$0")"

WORK=work

missing=0
for tool in verilog2hif muffin hif2verilog iverilog vvp; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "error: '$tool' not found on PATH" >&2
        missing=1
    fi
done
if [ "$missing" -ne 0 ]; then
    echo "See the 'Prerequisites' section of README.md." >&2
    exit 1
fi

rm -rf "$WORK"
mkdir -p "$WORK"

echo "==> [1/6] Verilog -> HIF"
verilog2hif -o "$WORK/and2" and2.v

echo "==> [2/6] Enumerating faults"
muffin "$WORK/and2.hif.xml" --list-faults "$WORK/faults.json"
cat "$WORK/faults.json"

echo "==> [3/6] Instrumenting the design"
muffin "$WORK/and2.hif.xml" --instrument -o "$WORK/and2_instrumented.hif.xml"

echo "==> [4/6] Instrumented HIF -> Verilog"
# Run from inside work/: hif2verilog also drops HIF2VERILOG_01_Final_tree.hif*
# debug dumps in the current directory, and they belong with the artifacts.
( cd "$WORK" && hif2verilog and2_instrumented.hif.xml -D generated )
cat "$WORK/generated/and2.v"

echo "==> [5/6] Compiling with Icarus Verilog"
iverilog -o "$WORK/sim" "$WORK/generated/and2.v" tb.v

echo "==> [6/6] Simulating"
vvp "$WORK/sim" | tee "$WORK/sim.log"

# vvp already exits non-zero on $fatal, but the pipe above hides its status,
# so assert on the testbench's own verdict line as well.
if ! grep -q "^RESULT: PASS" "$WORK/sim.log"; then
    echo "FAILED: the simulation did not report a passing result." >&2
    exit 1
fi

echo
echo "SUCCESS: golden, stuck-at-0 and stuck-at-1 all behaved as expected."
echo "Artifacts are in $(pwd)/$WORK."
