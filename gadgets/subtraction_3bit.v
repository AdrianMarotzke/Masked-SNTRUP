module subtraction_3bit #(parameter d=2) (
	clk,
	a_input, // a input is 3 bits, unsigned
	b_input, // b input is 3 bits, unsigned
	rnd,
	out_c    // c output is 4 bits, signed
);

	localparam and_pini_mul_nrnd = d*(d-1)/2;
	localparam and_pini_nrnd = and_pini_mul_nrnd;

	input  clk;
	input  [d*3-1:0] a_input;
	input  [d*3-1:0] b_input;
	input  [and_pini_nrnd*7-1:0] rnd;
	output [d*4-1:0] out_c;

	wire [d*3-1:0] a_input_reg;
	wire [d*3-1:0] a_input_reg2;
	wire [d*3-1:0] b_input_reg;
	wire [d*3-1:0] b_input_reg2;
	
	wire [d*3-1:0] neg_a_input_reg;
	
	wire [d-1:0] a0_xor_b0;
	wire [d-1:0] a0_xor_b0_reg;
	wire [d-1:0] a0_xor_b0_reg2;
	wire [d-1:0] a0_xor_b0_reg3;
	wire [d-1:0] a0_xor_b0_reg4;
	
	wire [d-1:0] n_a0_and_b0;
	
	wire [d-1:0] a1xb1_xor_a0b0;
	wire [d-1:0] a1xb1_xor_a0b0_reg;
	wire [d-1:0] a1xb1_xor_a0b0_reg2;
	wire [d-1:0] a1xb1_xor_a0b0_reg3;
	wire [d-1:0] a1xb1_xor_a0b0_reg4;
	
	wire [d-1:0] a1_xor_b1;
	wire [d-1:0] neg_a1_xor_b1;
	wire [d-1:0] a1_xor_b1_reg;
	wire [d-1:0] a1_and_b1;

	wire [d-1:0] a1xb1_and_a0b0;

	wire [d-1:0] carry_2;
	
	wire [d-1:0] carry_xor_a2b2;
	wire [d-1:0] carry_xor_a2b2_reg;
	wire [d-1:0] carry_xor_a2b2_reg2;

	wire [d-1:0] a2_xor_b2;
	wire [d-1:0] a2_xor_b2_reg;
	wire [d-1:0] a2_xor_b2_reg2;
	wire [d-1:0] neg_a2_xor_b2_reg;
	
	wire [d-1:0] a2_and_b2;
	wire [d-1:0] a2_and_b2_reg;
	wire [d-1:0] a2_and_b2_reg2;
	
	wire [d-1:0] a2b2_and_c2;

	wire [d-1:0] carry_3;
	
	MSKreg #(
	.d(d),
	.count(3)
	) MSKreg_instance (
		.clk(clk),
		.in_a(a_input),
		.out_a(a_input_reg)
	);

	MSKreg #(
	.d(d),
	.count(3)
	) MSKreg_instance2 (
		.clk(clk),
		.in_a(a_input_reg),
		.out_a(a_input_reg2)
	);
	
	MSKreg #(
	.d(d),
	.count(3)
	) MSKreg_instance3 (
		.clk(clk),
		.in_a(b_input),
		.out_a(b_input_reg)
	);

	MSKreg #(
	.d(d),
	.count(3)
	) MSKreg_instance4 (
		.clk(clk),
		.in_a(b_input_reg),
		.out_a(b_input_reg2)
	);

	MSKxor #(
	.d(d),
	.count(1)
	) MSKxor_instance_a0b0 (
		.ina(a_input_reg2[d-1:0]),
		.inb(b_input_reg2[d-1:0]),
		.out_c(a0_xor_b0)
	);

	MSKinv #(
		.d(d),
		.count(3)
	) MSKinv_instance_a (
		.in_a(a_input_reg),
		.out_a(neg_a_input_reg)
	);
	
	MSKand_HPC2 #(
	.d(d)
	) MSKand_HPC2_instance (
		.ina(neg_a_input_reg[d-1:0]),
		.inb(b_input[d-1:0]),
		.rnd(rnd[and_pini_nrnd-1:0]),
		.clk(clk),
		.out_c(n_a0_and_b0)
	);


	MSKxor #(
	.d(d),
	.count(1)
	) MSKxor_instance_a1b1 (
		.ina(a_input_reg[d*2-1:d]),
		.inb(b_input_reg[d*2-1:d]),
		.out_c(a1_xor_b1)
	);

	MSKreg #(
	.d(d),
	.count(1)
	) MSKreg_instance5 (
		.clk(clk),
		.in_a(a1_xor_b1),
		.out_a(a1_xor_b1_reg)
	);

	MSKxor #(
	.d(d),
	.count(1)
	) MSKxor_instance_a1b1_c1 (
		.ina(a1_xor_b1_reg),
		.inb(n_a0_and_b0),
		.out_c(a1xb1_xor_a0b0)
	);


	MSKand_HPC2 #(
	.d(d)
	) MSKand_HPC2_instance_a1b1 (
		.ina(neg_a_input_reg[d*2-1:d]),
		.inb(b_input[d*2-1:d]),
		.rnd(rnd[and_pini_nrnd*2-1:and_pini_nrnd]),
		.clk(clk),
		.out_c(a1_and_b1)
	);

	MSKinv #(
		.d(d),
		.count(1)
	) MSKinv_instance_a1b1 (
		.in_a(a1_xor_b1),
		.out_a(neg_a1_xor_b1)
	);
	
	MSKand_HPC2 #(
	.d(d)
	) MSKand_HPC2_instance_a1b1_c1 (
		.ina(n_a0_and_b0),
		.inb(neg_a1_xor_b1), // correct delay?
		.rnd(rnd[and_pini_nrnd*3-1:and_pini_nrnd*2]),
		.clk(clk),
		.out_c(a1xb1_and_a0b0)
	);

	MSKor_HPC2 #(
	.d(d)
	) MSKor_HPC2_instance (
		.clk(clk),
		.ina(a1xb1_and_a0b0),
		.inb(a1_and_b1), // correct delay?
		.rnd(rnd[and_pini_nrnd*4-1:and_pini_nrnd*3]),
		.out_c(carry_2)
	);

	MSKreg #(
	.d(d),
	.count(1)
	) MSKreg_instance6 (
		.clk(clk),
		.in_a(a1xb1_xor_a0b0),
		.out_a(a1xb1_xor_a0b0_reg)
	);
	
	MSKreg #(
	.d(d),
	.count(1)
	) MSKreg_instance7 (
		.clk(clk),
		.in_a(a1xb1_xor_a0b0_reg),
		.out_a(a1xb1_xor_a0b0_reg2)
	);
	MSKreg #(
	.d(d),
	.count(1)
	) MSKreg_instance12 (
		.clk(clk),
		.in_a(a1xb1_xor_a0b0_reg2),
		.out_a(a1xb1_xor_a0b0_reg3)
	);
	MSKreg #(
	.d(d),
	.count(1)
	) MSKreg_instance13 (
		.clk(clk),
		.in_a(a1xb1_xor_a0b0_reg3),
		.out_a(a1xb1_xor_a0b0_reg4)
	);
	
	MSKreg #(
	.d(d),
	.count(1)
	) MSKreg_instance8 (
		.clk(clk),
		.in_a(a0_xor_b0),
		.out_a(a0_xor_b0_reg)
	);
	MSKreg #(
	.d(d),
	.count(1)
	) MSKreg_instance9 (
		.clk(clk),
		.in_a(a0_xor_b0_reg),
		.out_a(a0_xor_b0_reg2)
	);
	MSKreg #(
	.d(d),
	.count(1)
	) MSKreg_instance10 (
		.clk(clk),
		.in_a(a0_xor_b0_reg2),
		.out_a(a0_xor_b0_reg3)
	);
	MSKreg #(
	.d(d),
	.count(1)
	) MSKreg_instance11 (
		.clk(clk),
		.in_a(a0_xor_b0_reg3),
		.out_a(a0_xor_b0_reg4)
	);

	MSKxor #(
		.d(d),
		.count(1)
	) MSKxor_instance (
		.ina(a2_xor_b2_reg2),
		.inb(carry_2),
		.out_c(carry_xor_a2b2)
	);
	
	
	MSKreg #(
		.d(d),
		.count(1)
	) MSKreg_instance_c_a2b2 (
		.clk(clk),
		.in_a(carry_xor_a2b2),
		.out_a(carry_xor_a2b2_reg)
	);
	
	MSKreg #(
		.d(d),
		.count(1)
	) MSKreg_instance_c_a2b2_2 (
		.clk(clk),
		.in_a(carry_xor_a2b2_reg),
		.out_a(carry_xor_a2b2_reg2)
	);
	
	MSKxor #(
	.d(d),
	.count(1)
	) MSKxor_instance_a2b2 (
		.ina(a_input_reg2[d*3-1:d*2]),
		.inb(b_input_reg2[d*3-1:d*2]),
		.out_c(a2_xor_b2)
	);

	MSKreg #(
	.d(d),
	.count(1)
	) MSKreg_instance_a2b2 (
		.clk(clk),
		.in_a(a2_xor_b2),
		.out_a(a2_xor_b2_reg)
	);
	MSKreg #(
	.d(d),
	.count(1)
	) MSKreg_instance_a2b2_2 (
		.clk(clk),
		.in_a(a2_xor_b2_reg),
		.out_a(a2_xor_b2_reg2)
	);

	MSKand_HPC2 #(
	.d(d)
	) MSKand_HPC2_instance_a2b2 (
		.ina(neg_a_input_reg[d*3-1:d*2]),
		.inb(b_input[d*3-1:d*2]),
		.rnd(rnd[and_pini_nrnd*5-1:and_pini_nrnd*4]),
		.clk(clk),
		.out_c(a2_and_b2)
	);	

	MSKinv #(
		.d(d),
		.count(1)
	) MSKinv_instance (
		.in_a(a2_xor_b2_reg),
		.out_a(neg_a2_xor_b2_reg)
	);
	
	MSKand_HPC2 #(
	.d(d)
	) MSKand_HPC2_instance_a2b2_c2 (
		.ina(carry_2),
		.inb(neg_a2_xor_b2_reg), // correct delay?
		.rnd(rnd[and_pini_nrnd*6-1:and_pini_nrnd*5]),
		.clk(clk),
		.out_c(a2b2_and_c2)
	);	
	
	MSKreg #(
		.d(d),
		.count(1)
	) MSKreg_instance_a2_and_b2 (
		.clk(clk),
		.in_a(a2_and_b2),
		.out_a(a2_and_b2_reg)
	);
	
	MSKreg #(
		.d(d),
		.count(1)
	) MSKreg_instance_a2_and_b2_2 (
		.clk(clk),
		.in_a(a2_and_b2_reg),
		.out_a(a2_and_b2_reg2)
	);

	MSKor_HPC2 #(
	.d(d)
	) MSKor_HPC2_instance_c3 (
		.clk(clk),
		.ina(a2b2_and_c2),
		.inb(a2_and_b2_reg2), // correct delay?
		.rnd(rnd[and_pini_nrnd*7-1:and_pini_nrnd*6]),
		.out_c(carry_3)
	);

	assign out_c[d-1:0] = a0_xor_b0_reg4;
	assign out_c[d*2-1:d] = a1xb1_xor_a0b0_reg4;
	assign out_c[d*3-1:d*2] = carry_xor_a2b2_reg2;
	assign out_c[d*4-1:d*3] = carry_3;		
endmodule
