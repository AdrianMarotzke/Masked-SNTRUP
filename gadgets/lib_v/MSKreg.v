// Masked register.
module MSKreg #(parameter d=1, parameter count=1) (clk, in_a, out_a);

	input clk;
	input  [count*d-1:0] in_a;
	output [count*d-1:0] out_a;

	reg [count*d-1:0] state;

	always @(posedge clk)
	state <= in_a;

	assign out_a = state;

endmodule
