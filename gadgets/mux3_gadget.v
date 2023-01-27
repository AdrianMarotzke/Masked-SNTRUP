module mux3_gadget #(parameter d=2, parameter word=13) (
	clk,
	a_input,
	b_input,
	s_input,
	rnd,
	out_mux
);

	localparam and_pini_mul_nrnd = d*(d-1)/2;
	localparam and_pini_nrnd = and_pini_mul_nrnd;

	input  clk;
	input  [d*word-1:0] a_input;
	input  [d*word-1:0] b_input;
	input  [d*2-1:0] s_input;
	input  [and_pini_nrnd*word*2-1:0] rnd;
	output [d*word-1:0] out_mux;

	wire [d*word-1:0] a_xor_b;
	wire [d*word-1:0] a_xor_b_reg;
	wire [d*word-1:0] b_input_reg;
	wire [d*word-1:0] b_input_reg2;
	wire [d*word-1:0] ab_and_s;
	wire [d*word-1:0] x0;
	wire  [d-1:0] s_input_0_reg;
	wire  [and_pini_nrnd*word-1:0] rnd_reg;

	MSKxor #(
	.d(d),
	.count(word)
	) MSKxor_instance (
		.ina(a_input),
		.inb(b_input),
		.out_c(a_xor_b)
	);

	MSKreg #(
	.d(d),
	.count(word)
	) MSKreg_instance (
		.clk(clk),
		.in_a(a_xor_b),
		.out_a(a_xor_b_reg)
	);

	genvar i;
	generate
		for (i = 0; i < word; i = i + 1) begin : block
			MSKand_HPC2 #(
			.d(d)
			) MSKand_HPC2_instance (
				.ina(a_xor_b_reg[i*d+d-1:i*d]),
				.inb(s_input[d*2-1:d]),
				.rnd(rnd[i*and_pini_nrnd+and_pini_nrnd-1:i*and_pini_nrnd]),
				.clk(clk),
				.out_c(ab_and_s[i*d+d-1:i*d])
			);
		end
	endgenerate

	MSKreg #(
	.d(d),
	.count(word)
	) MSKreg_instance2 (
		.clk(clk),
		.in_a(b_input),
		.out_a(b_input_reg)
	);

	MSKreg #(
	.d(d),
	.count(word)
	) MSKreg_instance3 (
		.clk(clk),
		.in_a(b_input_reg),
		.out_a(b_input_reg2)
	);

	MSKxor #(
	.d(d),
	.count(word)
	) MSKxor_instance2 (
		.ina(ab_and_s),
		.inb(b_input_reg2),
		.out_c(x0)
	);

	MSKreg #(
	.d(d),
	.count(1)
	) MSKreg_instance4 (
		.clk(clk),
		.in_a(s_input[d-1:0]),
		.out_a(s_input_0_reg)
	);

	MSKreg #(
		.d(1),  // simple reg, just for randomness
		.count(and_pini_nrnd*word)
	) MSKreg_instance5 (
		.clk(clk),
		.in_a(rnd[and_pini_nrnd*word*2-1:and_pini_nrnd*word]),
		.out_a(rnd_reg)
	);
	
	generate
		for (i = 0; i < word; i = i + 1) begin : block2
			MSKand_HPC2 #(
			.d(d)
			) MSKand_HPC2_instance2 (
				.ina(x0[i*d+d-1:i*d]),
				.inb(s_input_0_reg),
				.rnd(rnd_reg[i*and_pini_nrnd+and_pini_nrnd-1:i*and_pini_nrnd]),
				.clk(clk),
				.out_c(out_mux[i*d+d-1:i*d])
			);
		end
	endgenerate
endmodule
