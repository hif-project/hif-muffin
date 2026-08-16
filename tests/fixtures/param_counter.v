// The reproducer from issue #9: a parameterized-width counter. Used here for
// fault-enumeration metadata; the bit-level injection semantics are checked
// behaviorally on param_reg, which has no feedback to obscure them.
module param_counter #(parameter WIDTH = 4) (
    input clk,
    input rst,
    input en,
    output reg [WIDTH-1:0] count
);
    always @(posedge clk) begin
        count <= rst ? {WIDTH{1'b0}} : (en ? count + 1'b1 : count);
    end
endmodule
