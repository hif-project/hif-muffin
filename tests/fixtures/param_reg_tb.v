// Behavioral check that a stuck-at fault on a parameterized-width signal
// actually behaves like a stuck-at fault on ONE bit.
//
// The DUT is the Muffin-instrumented, hif2verilog-regenerated param_reg, so it
// carries the extra muffinMutPort input. For a WIDTH=4 register this is a
// complete check: 4 patterns x (golden + 8 faults).
//
// Before the fix this testbench could not even be written -- Muffin reported
// the register as 1 bit wide and the injector replaced the whole register with
// a literal, so `q` was 0 or 1 regardless of `d`.

`timescale 1ns / 1ps

module param_reg_tb;

    localparam WIDTH = 4;
    localparam PATTERNS = 4;

    reg clk;
    reg [WIDTH-1:0] d;
    reg [31:0] muffinMutPort;
    wire [WIDTH-1:0] q;

    integer errors;
    integer bit_index;
    integer pattern_index;
    reg [WIDTH-1:0] patterns [0:PATTERNS-1];

    param_reg dut (
        .clk(clk),
        .d(d),
        .q(q),
        .muffinMutPort(muffinMutPort)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Drive one input vector and check the registered output against what the
    // active fault is supposed to produce.
    //
    // `forced_bit` is the bit the active fault sits on, or -1 for golden. Two
    // separate properties are asserted: the output equals the expected value,
    // and the output differs from the fault-free value in AT MOST the one bit
    // the fault is on -- the second is the property that actually failed
    // before the fix, when the injected value replaced the whole register.
    task apply_and_check;
        input [WIDTH-1:0] value;
        input [WIDTH-1:0] want;
        input integer forced_bit;
        reg [WIDTH-1:0] changed;
        reg [WIDTH-1:0] allowed;
        begin
            d = value;
            @(posedge clk);
            #1;

            changed = q ^ value;
            allowed = (forced_bit < 0) ? {WIDTH{1'b0}} : (1 << forced_bit);

            if (q !== want) begin
                $display("  FAIL  mut=%0d d=%b q=%b expected=%b", muffinMutPort, value, q, want);
                errors = errors + 1;
            end else if ((changed & ~allowed) != {WIDTH{1'b0}}) begin
                $display(
                    "  FAIL  mut=%0d d=%b q=%b changed bits outside bit %0d (changed=%b)",
                    muffinMutPort, value, q, forced_bit, changed);
                errors = errors + 1;
            end else begin
                $display("  ok    mut=%0d d=%b q=%b changed=%b", muffinMutPort, value, q, changed);
            end
        end
    endtask

    initial begin
        errors        = 0;
        muffinMutPort = 0;
        d             = {WIDTH{1'b0}};

        patterns[0] = 4'b0000;
        patterns[1] = 4'b1111;
        patterns[2] = 4'b1010;
        patterns[3] = 4'b0101;

        $display("");
        $display("=== muffinMutPort = 0: golden, q must track d exactly ===");
        for (pattern_index = 0; pattern_index < PATTERNS; pattern_index = pattern_index + 1) begin
            apply_and_check(patterns[pattern_index], patterns[pattern_index], -1);
        end

        // Enumeration order is location-major, then bit, then SA0 before SA1,
        // so bit b has SA0 id 2*b+1 and SA1 id 2*b+2. The companion CMake test
        // asserts that faults.json really is in this order, rather than this
        // testbench assuming it.
        for (bit_index = 0; bit_index < WIDTH; bit_index = bit_index + 1) begin
            $display("");
            $display("=== fault %0d: bit %0d stuck-at-0 ===", 2 * bit_index + 1, bit_index);
            muffinMutPort = 2 * bit_index + 1;
            for (pattern_index = 0; pattern_index < PATTERNS; pattern_index = pattern_index + 1) begin
                apply_and_check(
                    patterns[pattern_index], patterns[pattern_index] & ~(1 << bit_index), bit_index);
            end

            $display("");
            $display("=== fault %0d: bit %0d stuck-at-1 ===", 2 * bit_index + 2, bit_index);
            muffinMutPort = 2 * bit_index + 2;
            for (pattern_index = 0; pattern_index < PATTERNS; pattern_index = pattern_index + 1) begin
                apply_and_check(
                    patterns[pattern_index], patterns[pattern_index] | (1 << bit_index), bit_index);
            end
        end

        $display("");
        if (errors == 0) begin
            $display("RESULT: PASS - every fault forced exactly its own bit, leaving the others untouched.");
            $display("");
            $finish;
        end else begin
            $display("RESULT: FAIL - %0d check(s) failed.", errors);
            $display("");
            $fatal(1);
        end
    end

endmodule
