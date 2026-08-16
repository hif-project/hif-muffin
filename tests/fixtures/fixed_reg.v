// The fixed-width counterpart of param_reg: same shape, but the span bound is
// a literal. Muffin has always handled this correctly, so it is the control
// that proves the parameterized fix did not change fixed-width behavior.
module fixed_reg (
    input clk,
    input [3:0] d,
    output reg [3:0] q
);
    always @(posedge clk) begin
        q <= d;
    end
endmodule
