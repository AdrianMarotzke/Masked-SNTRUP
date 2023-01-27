module sha_sigma_L1_gadget  #(parameter d=2)(
	clk,
	x_input,
	out_L1
);
	localparam word = 64;

	input  clk;
	input  [d*word-1:0] x_input;
	output  [d*word-1:0] out_L1;
	
	wire  [d*word-1:0] x_ro_19;
	wire  [d*word-1:0] x_ro_61;
	wire  [d*word-1:0] x_sh_6;
	wire  [d*word-1:0] ro19_xor_ro61;
	
	
	assign x_ro_19 = {x_input[19*d-1:0], x_input[word*d-1:19*d]};
	assign x_ro_61 = {x_input[61*d-1:0], x_input[word*d-1:61*d]};
	assign x_sh_6 = {{d{6'h00}}, x_input[word*d-1:6*d]};
	
	MSKxor #(
		.d(d),
		.count(word)
	) MSKxor_instance1 (
		.ina(x_ro_19),
		.inb(x_ro_61),
		.out_c(ro19_xor_ro61)
	);
	
	MSKxor #(
		.d(d),
		.count(word)
	) MSKxor_instance2 (
		.ina(ro19_xor_ro61),
		.inb(x_sh_6),
		.out_c(out_L1)
	);
endmodule
