// A parameterized-width register. The span bound `WIDTH-1` reaches Muffin as
// an expression over a template parameter rather than a literal, which is the
// case that used to resolve to "width 1".
//
// Unlike the counter, this has a data input and no feedback, so the effect of a
// single stuck-at fault on the output is directly observable per input vector:
// q is just d, with one bit forced.
module param_reg #(parameter WIDTH = 4) (
    input clk,
    input [WIDTH-1:0] d,
    output reg [WIDTH-1:0] q
);
    always @(posedge clk) begin
        q <= d;
    end
endmodule
