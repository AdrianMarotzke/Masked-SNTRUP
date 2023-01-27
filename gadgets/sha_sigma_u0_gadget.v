module sha_sigma_u0_gadget  #(parameter d=2)(
	clk,
	x_input,
	out_u0
);
	localparam word = 64;

	input  clk;
	input  [d*word-1:0] x_input;
	output  [d*word-1:0] out_u0;
	
	wire  [d*word-1:0] x_ro_28;
	wire  [d*word-1:0] x_ro_34;
	wire  [d*word-1:0] x_ro_39;
	wire  [d*word-1:0] ro28_xor_ro34;
	
	
	assign x_ro_28 = {x_input[28*d-1:0], x_input[word*d-1:28*d]};
	assign x_ro_34 = {x_input[34*d-1:0], x_input[word*d-1:34*d]};
	assign x_ro_39 = {x_input[39*d-1:0], x_input[word*d-1:39*d]};
	
	MSKxor #(
		.d(d),
		.count(word)
	) MSKxor_instance1 (
		.ina(x_ro_28),
		.inb(x_ro_34),
		.out_c(ro28_xor_ro34)
	);
	
	MSKxor #(
		.d(d),
		.count(word)
	) MSKxor_instance2 (
		.ina(ro28_xor_ro34),
		.inb(x_ro_39),
		.out_c(out_u0)
	);
endmodule
