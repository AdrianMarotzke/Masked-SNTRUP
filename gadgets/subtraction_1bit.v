module subtraction_1bit #(parameter d=2) (
	clk,
	a_input,
	b_input,
	rnd,
	out_c
);

	localparam and_pini_mul_nrnd = d*(d-1)/2;
	localparam and_pini_nrnd = and_pini_mul_nrnd;

	input  clk;
	input  [d-1:0] a_input;
	input  [d-1:0] b_input;
	input  [and_pini_nrnd-1:0] rnd;
	output [d*2-1:0] out_c;

	wire [d-1:0] a_xor_b;
	wire [d-1:0] n_a_and_b;
	wire [d-1:0] a_input_reg;
	wire [d-1:0] neg_a_input_reg;
	wire [d-1:0] a_input_reg2;
	wire [d-1:0] b_input_reg;
	wire [d-1:0] b_input_reg2;


	MSKreg #(
	.d(d),
	.count(1)
	) MSKreg_instance (
		.clk(clk),
		.in_a(a_input),
		.out_a(a_input_reg)
	);

	MSKreg #(
	.d(d),
	.count(1)
	) MSKreg_instance2 (
		.clk(clk),
		.in_a(a_input_reg),
		.out_a(a_input_reg2)
	);

	MSKreg #(
	.d(d),
	.count(1)
	) MSKreg_instance3 (
		.clk(clk),
		.in_a(b_input),
		.out_a(b_input_reg)
	);

	MSKreg #(
	.d(d),
	.count(1)
	) MSKreg_instance4 (
		.clk(clk),
		.in_a(b_input_reg),
		.out_a(b_input_reg2)
	);

	MSKxor #(
	.d(d),
	.count(1)
	) MSKxor_instance (
		.ina(a_input_reg2),
		.inb(b_input_reg2),
		.out_c(a_xor_b)
	);

	MSKinv #(
		.d(d),
		.count(1)
	) MSKinv_instance (
		.in_a(a_input_reg),
		.out_a(neg_a_input_reg)
	);
	
	MSKand_HPC2 #(
	.d(d)
	) MSKand_HPC2_instance (
		.ina(neg_a_input_reg),
		.inb(b_input),
		.rnd(rnd),
		.clk(clk),
		.out_c(n_a_and_b)
	);

	assign out_c[d-1:0] = a_xor_b;
	assign out_c[d*2-1:d] = n_a_and_b;


endmodule
