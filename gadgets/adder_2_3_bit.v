module adder_2_3_bit #(parameter d=2) (
	clk,
	a_input, // a input is 3 bits
	b_input, // b input is 2 bits
	rnd,
	out_c    // c output is 3 bits
);

	localparam and_pini_mul_nrnd = d*(d-1)/2;
	localparam and_pini_nrnd = and_pini_mul_nrnd;

	input  clk;
	input  [d*3-1:0] a_input;
	input  [d*2-1:0] b_input;
	input  [and_pini_nrnd*4-1:0] rnd;
	output [d*3-1:0] out_c;


	wire [d-1:0] a0_xor_b0;
	wire [d-1:0] a0_xor_b0_reg;
	wire [d-1:0] a0_xor_b0_reg2;
	
	wire [d-1:0] a0_and_b0;
	wire [d-1:0] a1xb1_xor_a0b0_reg;
	wire [d-1:0] a1xb1_xor_a0b0_reg2;
	wire [d*3-1:0] a_input_reg;
	wire [d*3-1:0] a_input_reg2;
	wire [d*2-1:0] b_input_reg;
	wire [d*2-1:0] b_input_reg2;

	wire [d-1:0] a_input3_reg;
	wire [d-1:0] a_input3_reg2;
	
	wire [d-1:0] a1_xor_b1;
	wire [d-1:0] a1_xor_b1_reg;
	wire [d-1:0] a1_and_b1;

	wire [d-1:0] a1xb1_xor_a0b0;
	wire [d-1:0] a1xb1_and_a0b0;

	wire [d-1:0] carry_out;
	wire [d-1:0] carry_xo3_a3;

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
	.count(1)
	) MSKreg_instance_a3 (
		.clk(clk),
		.in_a(a_input_reg2[d*3-1:d*2]),
		.out_a(a_input3_reg)
	);
	
	MSKreg #(
	.d(d),
	.count(1)
	) MSKreg_instance_a3_2 (
		.clk(clk),
		.in_a(a_input3_reg),
		.out_a(a_input3_reg2)
	);
	
	MSKreg #(
	.d(d),
	.count(2)
	) MSKreg_instance3 (
		.clk(clk),
		.in_a(b_input),
		.out_a(b_input_reg)
	);

	MSKreg #(
	.d(d),
	.count(2)
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

	MSKand_HPC2 #(
	.d(d)
	) MSKand_HPC2_instance (
		.ina(a_input_reg[d-1:0]),
		.inb(b_input[d-1:0]),
		.rnd(rnd[and_pini_nrnd-1:0]),
		.clk(clk),
		.out_c(a0_and_b0)
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
		.inb(a0_and_b0),
		.out_c(a1xb1_xor_a0b0)
	);


	MSKand_HPC2 #(
	.d(d)
	) MSKand_HPC2_instance_a1b1 (
		.ina(a_input_reg[d*2-1:d]),
		.inb(b_input[d*2-1:d]),
		.rnd(rnd[and_pini_nrnd*2-1:and_pini_nrnd]),
		.clk(clk),
		.out_c(a1_and_b1)
	);

	MSKand_HPC2 #(
	.d(d)
	) MSKand_HPC2_instance_a1b1_c1 (
		.ina(a0_and_b0),
		.inb(a1_xor_b1), // correct delay?
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
		.out_c(carry_out)
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

	MSKxor #(
		.d(d),
		.count(1)
	) MSKxor_instance (
		.ina(a_input3_reg2),
		.inb(carry_out),
		.out_c(carry_xo3_a3)
	);
	assign out_c[d-1:0] = a0_xor_b0_reg2;
	assign out_c[d*2-1:d] = a1xb1_xor_a0b0_reg2;
	assign out_c[d*3-1:d*2] = carry_xo3_a3;
	
endmodule
