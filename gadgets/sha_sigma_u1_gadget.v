module sha_sigma_u1_gadget  #(parameter d=2)(
	clk,
	x_input,
	out_u1
);
	localparam word = 64;

	input  clk;
	input  [d*word-1:0] x_input;
	output  [d*word-1:0] out_u1;
	
	wire  [d*word-1:0] x_ro_14;
	wire  [d*word-1:0] x_ro_18;
	wire  [d*word-1:0] x_ro_41;
	wire  [d*word-1:0] ro14_xor_ro18;
	
	
	assign x_ro_14 = {x_input[14*d-1:0], x_input[word*d-1:14*d]};
	assign x_ro_18 = {x_input[18*d-1:0], x_input[word*d-1:18*d]};
	assign x_ro_41 = {x_input[41*d-1:0], x_input[word*d-1:41*d]};
	
	MSKxor #(
		.d(d),
		.count(word)
	) MSKxor_instance1 (
		.ina(x_ro_14),
		.inb(x_ro_18),
		.out_c(ro14_xor_ro18)
	);
	
	MSKxor #(
		.d(d),
		.count(word)
	) MSKxor_instance2 (
		.ina(ro14_xor_ro18),
		.inb(x_ro_41),
		.out_c(out_u1)
	);
endmodule
