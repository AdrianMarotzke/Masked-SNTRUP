module sha_sigma_L0_gadget  #(parameter d=2)(
	clk,
	x_input,
	out_L0
);
	localparam word = 64;

	input  clk;
	input  [d*word-1:0] x_input;
	output  [d*word-1:0] out_L0;
	
	wire  [d*word-1:0] x_ro_1;
	wire  [d*word-1:0] x_ro_8;
	wire  [d*word-1:0] x_sh_7;
	wire  [d*word-1:0] ro1_xor_ro8;
	
	
	assign x_ro_1 = {x_input[1*d-1:0], x_input[word*d-1:1*d]};
	assign x_ro_8 = {x_input[8*d-1:0], x_input[word*d-1:8*d]};
	assign x_sh_7 = {{2{7'h00}}, x_input[word*d-1:7*d]};
	
	MSKxor #(
		.d(d),
		.count(word)
	) MSKxor_instance1 (
		.ina(x_ro_1),
		.inb(x_ro_8),
		.out_c(ro1_xor_ro8)
	);
	
	MSKxor #(
		.d(d),
		.count(word)
	) MSKxor_instance2 (
		.ina(ro1_xor_ro8),
		.inb(x_sh_7),
		.out_c(out_L0)
	);
endmodule
