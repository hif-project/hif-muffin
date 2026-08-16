// Child module for the hierarchical instrumentation test. Instantiated twice
// by hier_adder, which is what makes the per-design-unit fault model visible:
// both instances share one module body, so they share its fault ids.
module half_adder(input a, input b, output sum, output carry);
  assign sum   = a ^ b;
  assign carry = a & b;
endmodule
