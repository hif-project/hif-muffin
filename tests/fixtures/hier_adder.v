// Parent module for the hierarchical instrumentation test: two instances of
// half_adder plus one assignment of its own.
//
// Translated with `verilog2hif -s` the instances survive into HIF, so
// MutPortInjector::visitInstance runs and threads muffinMutPort down to both.
// Translated without `-s` (the default) the frontend inlines them and Muffin
// sees a single flat view -- see tests/hierarchical_wiring_test.cmake.
module hier_adder(input a, input b, input cin, output sum, output cout);
  wire s1, c1, c2;
  half_adder u_ha1(.a(a),  .b(b),   .sum(s1),  .carry(c1));
  half_adder u_ha2(.a(s1), .b(cin), .sum(sum), .carry(c2));
  assign cout = c1 | c2;
endmodule
