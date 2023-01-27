module mux2_gadget #(parameter d=2, parameter word=13) (
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
	input  [d-1:0] s_input;
	input  [and_pini_nrnd*word-1:0] rnd;
	output [d*word-1:0] out_mux;

	wire [d*word-1:0] a_xor_b;
	wire [d*word-1:0] a_xor_b_reg;
	wire [d*word-1:0] b_input_reg;
	wire [d*word-1:0] b_input_reg2;
	wire [d*word-1:0] ab_and_s;

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
				.inb(s_input),
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
		.out_c(out_mux)
	);
endmodule
