// Masked XOR gate
module MSKxor #(parameter d=1, parameter count=1) (ina, inb, out_c);

	input  [count*d-1:0] ina, inb;
	output [count*d-1:0] out_c;

	assign out_c = ina ^ inb ;

endmodule
