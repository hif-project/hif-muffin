// The control for multi_location_assign.v: the same two fault locations on one
// signal, written as a procedural block instead of two continuous assignments.
// Regression fixture for issue #24.
//
// This form was always attributed correctly, because the Assign the parser
// built is the one that survives into the HIF - there is no cone rewrite, and
// so no synthesized write-back to lose the statement's position. It is here so
// that the two forms are asserted to agree: a future regression in the shared
// reporting path fails on both fixtures, which distinguishes it from the
// frontend-specific defect #24 actually was.
//
// Deliberately the same design as multi_location_assign.v, so any difference
// between the two reports is about the form and nothing else. It produces two
// locations rather than four, because the partial signals the continuous form
// needs do not exist here.
//
// iverilog -g2005 accepts this file.
module multi_location_proc (input [7:0] a, output reg [7:0] y);
  always @(*) begin
    y[7:4] = a[3:0];
    y[3:0] = a[7:4];
  end
endmodule
