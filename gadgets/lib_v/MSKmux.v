// Masked 2-input MUX (non-sensitive control signal).
module MSKmux #(parameter d=1, parameter count=1) (sel, in_true, in_false, out);

	input sel;
	input  [count*d-1:0] in_true;
	input  [count*d-1:0] in_false;
	output [count*d-1:0] out;

	assign out = sel ? in_true : in_false;

endmodule
