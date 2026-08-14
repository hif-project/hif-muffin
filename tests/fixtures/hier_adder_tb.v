// Behavioral check that hierarchical instrumentation is correct, not merely
// wired (issue #10).
//
// The DUT is the Muffin-instrumented, hif2verilog-regenerated hier_adder, so
// it carries the extra muffinMutPort input and instantiates an instrumented
// half_adder twice. The sweep is exhaustive over the three functional inputs
// for golden and for four selected faults.
//
// Until hif-project/hif-backend#26 was fixed this testbench could not be run
// at all: the regenerated parent declared its instance-connected nets as `reg`,
// which Verilog forbids as the target of an instance output, so Icarus rejected
// the design at elaboration.
//
// Faults 1 and 3 sit in the child, and both instances share one module body -
// that is the per-design-unit (not per-instance) fault model recorded in
// docs/known-limitations.md. The oracles below encode that: selecting fault 1
// forces `sum` to 0 in u_ha1 *and* u_ha2, which is why `cout` degenerates to
// a & b rather than staying a full-adder carry. A future per-instance model
// would change these expectations, and this testbench is where that shows up.

`timescale 1ns / 1ps

module hier_adder_tb;

    reg a;
    reg b;
    reg cin;
    reg [31:0] muffinMutPort;
    wire sum;
    wire cout;

    integer errors;
    integer i;

    hier_adder dut (
        .a(a),
        .b(b),
        .cin(cin),
        .sum(sum),
        .cout(cout),
        .muffinMutPort(muffinMutPort)
    );

    task check;
        input want_sum;
        input want_cout;
        input [8*40:1] label;
        begin
            #1;
            if (sum === want_sum && cout === want_cout) begin
                $display("  ok    mut=%0d a=%b b=%b cin=%b  sum=%b cout=%b   %0s",
                         muffinMutPort, a, b, cin, sum, cout, label);
            end else begin
                $display("  FAIL  mut=%0d a=%b b=%b cin=%b  sum=%b cout=%b  expected sum=%b cout=%b   %0s",
                         muffinMutPort, a, b, cin, sum, cout, want_sum, want_cout, label);
                errors = errors + 1;
            end
        end
    endtask

    // One exhaustive pass over a/b/cin with the given fault selected. `mode`
    // picks the oracle rather than a value, so each expectation stays written
    // as a function of the inputs.
    task sweep;
        input [31:0] id;
        input integer mode;
        begin
            muffinMutPort = id;
            for (i = 0; i < 8; i = i + 1) begin
                a   = i[0];
                b   = i[1];
                cin = i[2];
                case (mode)
                    // Fault-free: a full adder.
                    0: check(a ^ b ^ cin, (a & b) | ((a ^ b) & cin), "golden");
                    // cout stuck-at in the parent: sum is untouched.
                    1: check(a ^ b ^ cin, 1'b0,                      "fault 5, cout SA0");
                    2: check(a ^ b ^ cin, 1'b1,                      "fault 6, cout SA1");
                    // Child sum SA0, in both instances: u_ha1 forces s1 to 0
                    // and u_ha2 forces the top-level sum to 0, so c2 = 0 & cin
                    // is 0 too and cout collapses to c1 = a & b.
                    3: check(1'b0,        a & b,                     "fault 1, child sum SA0 (both inst)");
                    // Child carry SA0, in both instances: c1 and c2 are both
                    // 0, so cout is 0; the sum path is untouched.
                    4: check(a ^ b ^ cin, 1'b0,                      "fault 3, child carry SA0 (both inst)");
                endcase
            end
        end
    endtask

    initial begin
        errors = 0;

        $display("");
        $display("=== muffinMutPort = 0: golden, must behave as a full adder ===");
        sweep(0, 0);

        $display("");
        $display("=== fault 5: cout stuck-at-0 (parent's own logic) ===");
        sweep(5, 1);

        $display("");
        $display("=== fault 6: cout stuck-at-1 (parent's own logic) ===");
        sweep(6, 2);

        $display("");
        $display("=== fault 1: child sum stuck-at-0, shared by both instances ===");
        sweep(1, 3);

        $display("");
        $display("=== fault 3: child carry stuck-at-0, shared by both instances ===");
        sweep(3, 4);

        $display("");
        if (errors == 0) begin
            $display("RESULT: PASS - hierarchical instrumentation behaves exactly as enumerated.");
            $display("");
            $finish;
        end else begin
            $display("RESULT: FAIL - %0d check(s) failed.", errors);
            $display("");
            $fatal(1);
        end
    end

endmodule
