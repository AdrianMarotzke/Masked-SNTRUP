module mod3_gadget #(parameter d=2) (
	clk,
	a_input, // unsigned 13 bit input
	rnd,
	out_mod  // signed 2 bit output
);

	localparam and_pini_mul_nrnd = d*(d-1)/2;
	localparam and_pini_nrnd = and_pini_mul_nrnd;

	input  clk;
	input  [d*13-1:0] a_input;
	input  [and_pini_nrnd*40-1:0] rnd;
	output [d*2-1:0] out_mod;

	wire [d*2-1:0] add_0_2;
	wire [d*2-1:0] add_1_3;
	wire [d*2-1:0] add_4_6;
	wire [d*2-1:0] add_5_7;
	wire [d*2-1:0] add_8_10;
	wire [d*2-1:0] add_9_11;
	
	wire [d-1:0] reg_input_a_12;
	wire [d-1:0] reg2_input_a_12;
	
	wire [d*3-1:0] add_02_46;
	wire [d*3-1:0] add_13_57;
	wire [d*3-1:0] add_810_12;
	
	wire [d*2-1:0] reg_add_9_11;
	wire [d*2-1:0] reg2_add_9_11;
	wire [d*2-1:0] reg3_add_9_11;
	wire [d*2-1:0] reg4_add_9_11;
	
	wire [d*3-1:0] add_path_a;
	wire [d*3-1:0] add_path_b;
	
	wire [d*4-1:0] sub_out;
	
	wire [d*2-1:0] add_s_2_3;
	wire [d*2-1:0] sub_s_0_1;
	
	wire [d*3-1:0] add_s23_s01;
	wire [d*3-1:0] add_s23_s01_reg;
	wire [d*3-1:0] add_s23_s01_reg2;
	
	wire [d-1:0] reg_out_mod;
	wire [d-1:0] reg1_out_mod;
	
	wire [d-1:0] xor_partial;
	
	wire [d-1:0] and_xor_partial;
	wire [d-1:0] and_partial;
	
	adder_1bit #(
		.d(d)
	) adder_1bit_instance_0_2 (
		.clk(clk),
		.a_input(a_input[d-1:0]), 		// bit 0
		.b_input(a_input[d*3-1:d*2]),	// bit 2
		.rnd(rnd[and_pini_nrnd-1:0]),
		.out_c(add_0_2)
	);
	
	adder_1bit #(
		.d(d)
	) adder_1bit_instance_1_3 (
		.clk(clk),
		.a_input(a_input[d*2-1:d]), 	// bit 1
		.b_input(a_input[d*4-1:d*3]),	// bit 3
		.rnd(rnd[and_pini_nrnd*2-1:and_pini_nrnd]),
		.out_c(add_1_3)
	);
	
	adder_1bit #(
		.d(d)
	) adder_1bit_instance_4_6 (
		.clk(clk),
		.a_input(a_input[d*5-1:d*4]), 	// bit 4
		.b_input(a_input[d*7-1:d*6]),	// bit 6
		.rnd(rnd[and_pini_nrnd*3-1:and_pini_nrnd*2]),
		.out_c(add_4_6)
	);
	
	adder_1bit #(
		.d(d)
	) adder_1bit_instance_5_7 (
		.clk(clk),
		.a_input(a_input[d*6-1:d*5]), 	// bit 5
		.b_input(a_input[d*8-1:d*7]),	// bit 7
		.rnd(rnd[and_pini_nrnd*4-1:and_pini_nrnd*3]),
		.out_c(add_5_7)
	);
	
	adder_1bit #(
		.d(d)
	) adder_1bit_instance_8_10 (
		.clk(clk),
		.a_input(a_input[d*9-1:d*8]), 	// bit 8
		.b_input(a_input[d*11-1:d*10]),	// bit 10
		.rnd(rnd[and_pini_nrnd*5-1:and_pini_nrnd*4]),
		.out_c(add_8_10)
	);
	
	adder_1bit #(
		.d(d)
	) adder_1bit_instance_9_11 (
		.clk(clk),
		.a_input(a_input[d*10-1:d*9]), 	// bit 9
		.b_input(a_input[d*12-1:d*11]),	// bit 11
		.rnd(rnd[and_pini_nrnd*6-1:and_pini_nrnd*5]),
		.out_c(add_9_11)
	);
	
	MSKreg #(
		.d(d),
		.count(1)
	) MSKreg_instance_reg_a_12 (
		.clk(clk),
		.in_a(a_input[d*13-1:d*12]),
		.out_a(reg_input_a_12)
	);
	
	MSKreg #(
		.d(d),
		.count(1)
	) MSKreg_instance_reg2_a_12 (
		.clk(clk),
		.in_a(reg_input_a_12),
		.out_a(reg2_input_a_12)
	);
	
	adder_2bit #(
		.d(d)
	) adder_2bit_instance_02_46 (
		.clk(clk),
		.a_input(add_0_2),
		.b_input(add_4_6),
		.rnd(rnd[and_pini_nrnd*10-1:and_pini_nrnd*6]),
		.out_c(add_02_46)
	);
	
	adder_2bit #(
		.d(d)
	) adder_2bit_instance_13_57 (
		.clk(clk),
		.a_input(add_1_3),
		.b_input(add_5_7),
		.rnd(rnd[and_pini_nrnd*14-1:and_pini_nrnd*10]),
		.out_c(add_13_57)
	);
	
	adder_2bit #(
		.d(d)
	) adder_2bit_instance_810_12 ( // This can be optimized, to an adder with 2 bit out instead of 3
		.clk(clk),
		.a_input(add_8_10),
		.b_input({{d{1'b0}}, reg2_input_a_12}),
		.rnd(rnd[and_pini_nrnd*18-1:and_pini_nrnd*14]),
		.out_c(add_810_12)
	);
	
	MSKreg #(
		.d(d),
		.count(2)
	) MSKreg_instance_add_9_11 (
		.clk(clk),
		.in_a(add_9_11),
		.out_a(reg_add_9_11)
	);
	
	MSKreg #(
		.d(d),
		.count(2)
	) MSKreg_instance2_add_9_11 (
		.clk(clk),
		.in_a(reg_add_9_11),
		.out_a(reg2_add_9_11)
	);
	
	MSKreg #(
		.d(d),
		.count(2)
	) MSKreg_instance3_add_9_11 (
		.clk(clk),
		.in_a(reg2_add_9_11),
		.out_a(reg3_add_9_11)
	);
	
	MSKreg #(
		.d(d),
		.count(2)
	) MSKreg_instance4_add_9_11 (
		.clk(clk),
		.in_a(reg3_add_9_11),
		.out_a(reg4_add_9_11)
	);

	adder_2_3_bit #(
		.d(d)
	) adder_2_3_bit_instance_a (
		.clk(clk),
		.a_input(add_13_57),
		.b_input(reg4_add_9_11),
		.rnd(rnd[and_pini_nrnd*22-1:and_pini_nrnd*18]),
		.out_c(add_path_a)
	);
	
	adder_2_3_bit #(
		.d(d)
	) adder_2_3_bit_instance_b (
		.clk(clk),
		.a_input(add_02_46),
		.b_input(add_810_12[d*2-1:0]),
		.rnd(rnd[and_pini_nrnd*26-1:and_pini_nrnd*22]),
		.out_c(add_path_b)
	);
	
	subtraction_3bit #(
		.d(d)
	) subtraction_3bit_instance (
		.clk(clk),
		.a_input(add_path_b),
		.b_input(add_path_a),
		.rnd(rnd[and_pini_nrnd*33-1:and_pini_nrnd*26]),
		.out_c(sub_out)
	);
	
	adder_1bit #(
		.d(d)
	) adder_1bit_instance_s_2_3 (
		.clk(clk),
		.a_input(sub_out[d*4-1:d*3]),
		.b_input(sub_out[d*3-1:d*2]),
		.rnd(rnd[and_pini_nrnd*34-1:and_pini_nrnd*33]),
		.out_c(add_s_2_3)
	);
	
	subtraction_1bit #(
		.d(d)
	) subtraction_1bit_instance (
		.clk(clk),
		.a_input(sub_out[d-1:0]),
		.b_input(sub_out[d*2-1:d]),
		.rnd(rnd[and_pini_nrnd*35-1:and_pini_nrnd*34]),
		.out_c(sub_s_0_1)
	);
	
	adder_2_3_bit #(
		.d(d)
	) adder_2bit_instance (
		.clk(clk),
		.a_input({sub_s_0_1[d*2-1:d], sub_s_0_1}), // TODO check if this duplication is ok
		.b_input(add_s_2_3),
		.rnd(rnd[and_pini_nrnd*39-1:and_pini_nrnd*35]),
		.out_c(add_s23_s01)
	);
	
	MSKxor #(
		.d(d),
		.count(1)
	) MSKxor_instance (
		.ina(add_s23_s01[d-1:0]),
		.inb(add_s23_s01[d*2-1:d]),
		.out_c(xor_partial)
	);
	
	MSKxor #(
		.d(d),
		.count(1)
	) MSKxor_instance2 (
		.ina(xor_partial),
		.inb(add_s23_s01[d*3-1:d*2]),
		.out_c(reg_out_mod)
	);
	
	MSKreg #(
		.d(d),
		.count(1)
	) MSKreg_instance (
		.clk(clk),
		.in_a(reg_out_mod),
		.out_a(reg1_out_mod)
	);
	MSKreg #(
		.d(d),
		.count(1)
	) MSKreg_instance1 (
		.clk(clk),
		.in_a(reg1_out_mod),
		.out_a(out_mod[d-1:0])
	);
	
	MSKreg #(
		.d(d),
		.count(3)
	) MSKreg_instance2 (
		.clk(clk),
		.in_a(add_s23_s01),
		.out_a(add_s23_s01_reg)
	);
	
	MSKreg #(
		.d(d),
		.count(3)
	) MSKreg_instance3 (
		.clk(clk),
		.in_a(add_s23_s01_reg),
		.out_a(add_s23_s01_reg2)
	);
	
	
	MSKand_HPC2 #(
	.d(d)
	) MSKand_HPC2_instance (
		.ina(add_s23_s01_reg[d*2-1:d]),
		.inb(add_s23_s01[d-1:0]),
		.rnd(rnd[and_pini_nrnd*40-1:and_pini_nrnd*39]),
		.clk(clk),
		.out_c(and_partial)
	);
	
	MSKxor #(
		.d(d),
		.count(1)
	) MSKxor_instance3 (
		.ina(and_partial),
		.inb(add_s23_s01_reg2[d*2-1:d]),
		.out_c(and_xor_partial)
	);

	MSKxor #(
		.d(d),
		.count(1)
	) MSKxor_instance4 (
		.ina(and_xor_partial),
		.inb(add_s23_s01_reg2[d*3-1:d*2]),
		.out_c(out_mod[d*2-1:d])
	);
endmodule
