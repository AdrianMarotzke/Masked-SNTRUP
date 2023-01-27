module mul3_gadget #(parameter d=2) (
	clk,
	e_input,
	v_input,
	a_input,
	rnd,
	out_mul3
);

	localparam and_pini_mul_nrnd = d*(d-1)/2;
	localparam and_pini_nrnd = and_pini_mul_nrnd;

	input  clk;
	input  [d*2-1:0] e_input;
	input  [d*2-1:0] v_input;
	input  [d*2-1:0] a_input;
	input  [and_pini_nrnd*6-1:0] rnd;
	output [d*2-1:0] out_mul3;

	reg  [and_pini_nrnd*6-1:0] rnd_1;
	reg  [and_pini_nrnd*6-1:0] rnd_2;
	reg  [and_pini_nrnd*6-1:0] rnd_3;

	wire  [d*2-1:0] a_input_reg1;
	wire  [d*2-1:0] a_input_reg2;
	wire  [d*2-1:0] a_input_reg3;

	wire  [d*2-1:0] e_reg;
	wire  [d-1:0] r0;

	wire  [d-1:0] a0;
	wire  [d-1:0] a0_pre;
	wire  [d-1:0] a1;
	wire  [d-1:0] a1_pre;

	wire  [d-1:0] e0_and_v0;
	wire  [d-1:0] e1_xor_v1;
	wire  [d-1:0] e1_xor_v1_reg;

	wire  [d-1:0] r1;
	wire  [d-1:0] r1_reg;
	wire  [d-1:0] r1_reg2;

	wire  [d-1:0] r1_xor_a1;
	wire  [d-1:0] r1_xor_a1_inv;

	wire  [d-1:0] r0_and_inv_r1a1;
	wire  [d-1:0] r0_xor_a0;

	wire  [d-1:0] r0_xor_a1;
	wire  [d-1:0] r0_xor_a1_reg;
	wire  [d-1:0] r0_xor_a1_reg2;
	wire  [d-1:0] inv_a1r0;
	wire  [d-1:0] r1_and_inv_r0a1;
	
	wire  [d-1:0] intermediate;

	wire  [d-1:0] a0_intermediate;


	always @(posedge clk) begin
		rnd_1 <= rnd;
		rnd_2 <= rnd_1;
		rnd_3 <= rnd_2;
	end


	MSKreg #(
	.d(d),
	.count(2)
	) MSKreg_instance (
		.clk(clk),
		.in_a(e_input),
		.out_a(e_reg) // 1 clock cycle delay
	);

	MSKand_HPC2 #(
	.d(d)
	) MSKand_HPC2_instance_e0v0 (
		.ina(e_reg[d-1:0]),
		.inb(v_input[d-1:0]),
		.rnd(rnd[and_pini_nrnd-1:0]),
		.clk(clk),
		.out_c(e0_and_v0) // 2 clock cycle delay
	);

	MSKxor #(
	.d(d),
	.count(1)
	) MSKxor_instance_e1v1 (
		.ina(e_input[d*2-1:d]),
		.inb(v_input[d*2-1:d]),
		.out_c(e1_xor_v1) // 0 clock cycle delay
	);

	MSKreg #(
	.d(d),
	.count(1)
	) MSKreg_instance1 (
		.clk(clk),
		.in_a(e1_xor_v1),
		.out_a(e1_xor_v1_reg) // 1 clock cycle delay
	);

	MSKand_HPC2 #(
	.d(d)
	) MSKand_HPC2_instance_r1 (
		.ina(e0_and_v0),
		.inb(e1_xor_v1_reg),
		.rnd(rnd[and_pini_nrnd*2-1:and_pini_nrnd]),
		.clk(clk),
		.out_c(r1) // 3 clock cycle delay
	);

	MSKreg #(
	.d(d),
	.count(1)
	) MSKreg_instance3 (
		.clk(clk),
		.in_a(e0_and_v0),
		.out_a(r0) // 3 clock cycle delay
	);

	MSKreg #(
	.d(d),
	.count(2)
	) MSKreg_instance_a_reg1 (
		.clk(clk),
		.in_a(a_input),
		.out_a(a_input_reg1)
	);
	MSKreg #(
	.d(d),
	.count(2)
	) MSKreg_instance_a_reg2 (
		.clk(clk),
		.in_a(a_input_reg1),
		.out_a(a_input_reg2)
	);
	MSKreg #(
	.d(d),
	.count(2)
	) MSKreg_instance_a_reg3 (
		.clk(clk),
		.in_a(a_input_reg2),
		.out_a(a_input_reg3)
	);

	assign a0 = a_input_reg3[d-1:0];
	assign a1 = a_input_reg3[2*d-1:d];

	assign a0_pre = a_input_reg2[d-1:0];
	assign a1_pre = a_input_reg2[2*d-1:d];

	MSKxor #(
	.d(d),
	.count(1)
	) MSKxor_instance_r1a1 (
		.ina(r1),
		.inb(a1),
		.out_c(r1_xor_a1) // 3 clock cycle delay
	);

	MSKinv #(
	.d(d),
	.count(1)
	) MSKinv_instance (
		.in_a(r1_xor_a1),
		.out_a(r1_xor_a1_inv) // 3 clock cycle delay
	);

	MSKand_HPC2 #(
	.d(d)
	) MSKand_HPC2_instance_r0_r1a1_inv (
		.ina(r1_xor_a1_inv),
		.inb(e0_and_v0), // use this instead of r0, as it has 1 cycle delay less
		.rnd(rnd[and_pini_nrnd*3-1:and_pini_nrnd*2]),
		.clk(clk),
		.out_c(r0_and_inv_r1a1) // 4 clock cycle delay
	);

	MSKxor #(
	.d(d),
	.count(1)
	) MSKxor_instance_r0a0 (
		.ina(r0),
		.inb(a0),
		.out_c(r0_xor_a0) // 3 clock cycle delay
	);

	MSKor_HPC2 #(
	.d(d)
	) MSKor_HPC2_instance_out0 (
		.ina(r0_and_inv_r1a1),
		.inb(r0_xor_a0),
		.rnd(rnd[and_pini_nrnd*4-1:and_pini_nrnd*3]),
		.clk(clk),
		.out_c(out_mul3[d-1:0]) // 5 clock cycle delay
	);



	MSKxor #(
	.d(d),
	.count(1)
	) MSKxor_instance_a1r0 (
		.ina(a1_pre),
		.inb(e0_and_v0), // use this instead of r0, as it has 1 cycle delay less
		.out_c(r0_xor_a1) // 2 clock cycle delay
	);

	MSKreg #(
	.d(d),
	.count(1)
	) MSKreg_instance_r0a1 (
		.clk(clk),
		.in_a(r0_xor_a1),
		.out_a(r0_xor_a1_reg) // 3 clock cycle delay
	);

	MSKreg #(
	.d(d),
	.count(1)
	) MSKreg_instance_r0a1_2 (
		.clk(clk),
		.in_a(r0_xor_a1_reg),
		.out_a(r0_xor_a1_reg2) // 4 clock cycle delay
	);

	MSKinv #(
	.d(d),
	.count(1)
	) MSKinv_instance_a1r0 (
		.in_a(r0_xor_a1),
		.out_a(inv_a1r0) // 2 clock cycle delay
	);

	MSKand_HPC2 #(
	.d(d)
	) MSKand_HPC2_instance_r1_inv_r0a1 (
		.ina(r1),
		.inb(inv_a1r0),
		.rnd(rnd[and_pini_nrnd*5-1:and_pini_nrnd*4]),
		.clk(clk),
		.out_c(r1_and_inv_r0a1) // 4 clock cycle delay
	);

	MSKxor #(
	.d(d),
	.count(1)
	) MSKxor_instance (
		.ina(r1_and_inv_r0a1),
		.inb(r0_xor_a1_reg2),
		.out_c(intermediate) // 4 clock cycle delay
	);

	MSKand_HPC2 #(
	.d(d)
	) MSKand_HPC2_instance_a0_intermediate (
		.ina(intermediate),
		.inb(a0),
		.rnd(rnd[and_pini_nrnd*6-1:and_pini_nrnd*5]),
		.clk(clk),
		.out_c(a0_intermediate) // 5 clock cycle delay
	);
	
	MSKreg #(
		.d(d),
		.count(1)
	) MSKreg_instance_r1 (
		.clk(clk),
		.in_a(r1),
		.out_a(r1_reg) // 4 clock cycle delay
	);
	
	MSKreg #(
		.d(d),
		.count(1)
	) MSKreg_instance_r1_2 (
		.clk(clk),
		.in_a(r1_reg),
		.out_a(r1_reg2) // 5 clock cycle delay
	);
	
	MSKxor #(
		.d(d),
		.count(1)
	) MSKxor_instance_final (
		.ina(a0_intermediate),
		.inb(r1_reg2),
		.out_c(out_mul3[2*d-1:d]) // 5 clock cycle delay
	);
endmodule