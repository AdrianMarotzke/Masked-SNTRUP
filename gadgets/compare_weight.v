module compare_weight #(parameter d=2) (
	clk,
	a_input,
	b_input,
	rnd,
	out_equal
);

	localparam and_pini_mul_nrnd = d*(d-1)/2;
	localparam and_pini_nrnd = and_pini_mul_nrnd;
	localparam word = 10;

	input  clk;
	input  [d*word-1:0] a_input;
	input  [d*word-1:0] b_input;
	input  [and_pini_nrnd*word-1:0] rnd;
	output [d-1:0] out_equal;

	wire  [d*word-1:0] a_xor_b;
	wire  [d*word-1:0] a_xor_b_reg[word-1:0];
	wire [d-1:0] or_out[word-1:0];

	//	wire [d-1:0] or_10;
	//	wire [d-1:0] or_32;
	//	wire [d-1:0] or_54;
	//	wire [d-1:0] or_76;
	//	wire [d-1:0] or_98;

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
		.out_a(a_xor_b_reg[0])
	);

	genvar i;
	generate
		for (i = 0; i < word-1; i = i + 1) begin : block1
			MSKreg #(
			.d(d),
			.count(word)
			) MSKreg_instance2 (
				.clk(clk),
				.in_a(a_xor_b_reg[i]),
				.out_a(a_xor_b_reg[i+1])
			);
		end
	endgenerate

	MSKor_HPC2 #(
	.d(d)
	) MSKor_HPC2_instance (
		.clk(clk),
		.ina(a_xor_b_reg[0][d-1:0]),
		.inb(a_xor_b[d*2-1:d]),
		.rnd(rnd[and_pini_nrnd-1:0]),
		.out_c(or_out[0])
	);

	genvar j;
	generate
		for (j = 0; j < word-1; j = j + 1) begin : block2
			MSKor_HPC2 #(
			.d(d)
			) MSKor_HPC2_instance2 (
				.clk(clk),
				.ina(or_out[j]),
				.inb(a_xor_b_reg[j][d*(j+1)-1:d*j]),
				.rnd(rnd[and_pini_nrnd*(j+2)-1:and_pini_nrnd*(j+1)]),
				.out_c(or_out[j+1])
			);
		end
	endgenerate

	assign out_equal = or_out[word-1];


	// Or all of a_xor_b together in a tree structure
	// Layer 1
	//
	//	MSKreg #(
	//	.d(d),
	//	.count(word)
	//	) MSKreg_instance (
	//		.clk(clk),
	//		.in(a_xor_b),
	//		.out(a_xor_b_reg)
	//	);
	//
	//	MSKor_HPC2 #(
	//	.d(d)
	//	) MSKor_HPC2_instance (
	//		.clk(clk),
	//		.ina(a_xor_b_reg[d-1:0]),
	//		.inb(a_xor_b[d*2-1:d]),
	//		.rnd(rnd[and_pini_nrnd-1:0]),
	//		.out(or_10)
	//	);
	//	
	//	MSKor_HPC2 #(
	//		.d(d)
	//	) MSKor_HPC2_instance2 (
	//		.clk(clk),
	//		.ina(a_xor_b_reg[d*3-1:d*2]),
	//		.inb(a_xor_b[d*4-1:d*3]),
	//		.rnd(rnd[and_pini_nrnd*2-1:and_pini_nrnd]),
	//		.out(or_32)
	//	);
	//	
	//	MSKor_HPC2 #(
	//		.d(d)
	//	) MSKor_HPC2_instance3 (
	//		.clk(clk),
	//		.ina(a_xor_b_reg[d*5-1:d*4]),
	//		.inb(a_xor_b[d*6-1:d*5]),
	//		.rnd(rnd[and_pini_nrnd*3-1:and_pini_nrnd*2]),
	//		.out(or_54)
	//	);
	//	
	//	MSKor_HPC2 #(
	//		.d(d)
	//	) MSKor_HPC2_instance4 (
	//		.clk(clk),
	//		.ina(a_xor_b_reg[d*7-1:d*6]),
	//		.inb(a_xor_b[d*8-1:d*7]),
	//		.rnd(rnd[and_pini_nrnd*4-1:and_pini_nrnd*3]),
	//		.out(or_76)
	//	);
	//	
	//	MSKor_HPC2 #(
	//		.d(d)
	//	) MSKor_HPC2_instance5 (
	//		.clk(clk),
	//		.ina(a_xor_b_reg[d*9-1:d*8]),
	//		.inb(a_xor_b[d*10-1:d*9]),
	//		.rnd(rnd[and_pini_nrnd*5-1:and_pini_nrnd*4]),
	//		.out(or_98)
	//	);


endmodule