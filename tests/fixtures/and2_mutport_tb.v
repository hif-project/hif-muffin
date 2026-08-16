// Proves that muffinMutPort alone activates and clears a fault.
//
// The contract under test, on a settled combinational design:
//
//   1. settle the DUT with muffinMutPort = 0;
//   2. change ONLY muffinMutPort to fault N  -> the output reflects the fault;
//   3. change ONLY muffinMutPort back to 0   -> the output returns to golden;
//   4. no functional input transition is required at any point.
//
// Before the fix for issue #16, Muffin rewrote the assignment to read
// muffinMutPort but left it out of the process's sensitivity list, so the
// instrumented logic did not re-evaluate and steps 2 and 3 silently did
// nothing until some unrelated input happened to toggle.
//
// `a` and `b` are driven once, at the start, and never again -- the test would
// be meaningless if the stimulus itself provoked re-evaluation.

`timescale 1ns / 1ps

module and2_mutport_tb;

    reg a;
    reg b;
    reg [31:0] muffinMutPort;
    wire y;

    integer errors;

    and2 dut (
        .a(a),
        .b(b),
        .y(y),
        .muffinMutPort(muffinMutPort)
    );

    // Change only the activation port, then check the output. No input is
    // touched here -- that is the whole point.
    task select_and_check;
        input [31:0] id;
        input expected;
        input [8*24:1] label;
        begin
            muffinMutPort = id;
            #1;
            if (y === expected) begin
                $display("  ok    mut=%0d  a=%b b=%b  y=%b   %0s", id, a, b, y, label);
            end else begin
                $display("  FAIL  mut=%0d  a=%b b=%b  y=%b expected=%b   %0s", id, a, b, y, expected, label);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors = 0;

        // Settle once. a and b are never touched again.
        a             = 1'b1;
        b             = 1'b1;
        muffinMutPort = 0;
        #1;

        if (y !== 1'b1) begin
            $display("  FAIL  golden did not settle: a=1 b=1 gave y=%b, expected 1", y);
            errors = errors + 1;
        end else begin
            $display("  ok    settled with mut=0, a=1 b=1, y=%b", y);
        end

        $display("");
        $display("=== changing only muffinMutPort, inputs held at a=1 b=1 ===");

        // a & b is 1 here, so SA0 on y is visible and SA1 is not.
        select_and_check(1, 1'b0, "fault 1 (SA0) active");
        select_and_check(0, 1'b1, "back to golden");
        select_and_check(2, 1'b1, "fault 2 (SA1) active");
        select_and_check(0, 1'b1, "back to golden");

        // Re-activating a fault after having cleared it must work too: a
        // process that latched on the first change only would pass the
        // sequence above but fail here.
        select_and_check(1, 1'b0, "fault 1 again");
        select_and_check(0, 1'b1, "golden again");

        $display("");
        if (errors == 0) begin
            $display("RESULT: PASS - muffinMutPort alone both activates and clears the fault.");
            $display("");
            $finish;
        end else begin
            $display("RESULT: FAIL - %0d check(s) failed.", errors);
            $display("");
            $fatal(1);
        end
    end

endmodule
