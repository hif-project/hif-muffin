// Two fault locations on one signal, written as two continuous assignments to
// different part-selects. Regression fixture for issue #24.
//
// Every other Muffin fixture here was deliberately written with one assignment
// per signal so that {signal, bit, type} stays unique - counter_load says so in
// a comment, as do pipeline3 and param_counter - so until this fixture no test
// exercised a signal with more than one fault location. That is the shape the
// attribute-based lookup in hif-regression has to work for, and the shape that
// was broken: both locations were reported with source "" and line 0, making
// eight pairs of records identical in every field but id.
//
// The halves are swapped rather than copied so that neither assignment can be
// folded into the other or reordered without changing the design, and the
// target is an output port because that is the reported shape. `y` ends up with
// two locations and the two frontend-synthesized partials with one each, so the
// fixture also covers the case where attributed and unattributed locations
// coexisted in one report.
//
// multi_location_proc.v is the same design as a procedural block. It was always
// attributed correctly, and the test runs it as a control so that a regression
// in the shared reporting path fails on both rather than looking like a
// frontend-specific problem.
//
// The fault report is the whole subject here, so the test stops at
// --list-faults and does not regenerate Verilog. Worth knowing while reading
// this fixture: hif2vhdl cannot emit this design at all - it aborts on any
// part-select assignment target, which is hif-backend#103 and reproduces with
// Muffin absent from the pipeline.
//
// iverilog -g2005 accepts this file.
module multi_location_assign (input [7:0] a, output [7:0] y);
  assign y[7:4] = a[3:0];
  assign y[3:0] = a[7:4];
endmodule
