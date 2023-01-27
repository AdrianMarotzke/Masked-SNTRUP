module sha_ma_gadget #(parameter d=2, parameter word=13) (
	clk,
	a_input,
	b_input,
	c_input,
	rnd,
	out_ma
);

	localparam and_pini_mul_nrnd = d*(d-1)/2;
	localparam and_pini_nrnd = and_pini_mul_nrnd;

	input  clk;
	input  [d*word-1:0] a_input;
	input  [d*word-1:0] b_input;
	input  [d*word-1:0] c_input;
	input  [and_pini_nrnd*2*word-1:0] rnd;
	output [d*word-1:0] out_ma;


	wire [d*word-1:0] a_reg;
	wire [d*word-1:0] b_reg;
	wire [d*word-1:0] a_and_b;
	wire [d*word-1:0] a_and_c;
	wire [d*word-1:0] b_and_c;
	wire [d*word-1:0] ab_xor_ac;
	wire [d*word-1:0] a_and_bc;
	wire [d*word-1:0] b_xor_c;
	wire [d*word-1:0] b_xor_c_reg;
	wire [and_pini_nrnd*word-1:0] rnd_a_and_bc;
	wire [and_pini_nrnd*word-1:0] rnd_b_and_c;


	assign rnd_b_and_c = rnd[and_pini_nrnd*word*2-1:and_pini_nrnd*word];
	assign rnd_a_and_bc = rnd[and_pini_nrnd*word-1:0];

	MSKreg #(
	.d(d),
	.count(word)
	) MSKreg_instance (
		.clk(clk),
		.in_a(b_xor_c),
		.out_a(b_xor_c_reg)
	);
	
	MSKreg #(
	.d(d),
	.count(word)
	) MSKreg_instance2 (
		.clk(clk),
		.in_a(b_input),
		.out_a(b_reg)
	);
	MSKxor #(
	.d(d),
	.count(word)
	) MSKxor_instance_ac (
		.ina(b_input),
		.inb(c_input),
		.out_c(b_xor_c)
	);

	MSKxor #(
	.d(d),
	.count(word)
	) MSKxor_instance (
		.ina(a_and_bc),
		.inb(b_and_c),
		.out_c(out_ma)
	);

	// unpack vector to matrix --> easier for handling
	genvar k,j;

	wire [d-1:0] a_input_mat [word-1:0];
	wire [d-1:0] b_reg_mat [word-1:0];
	wire [d-1:0] c_input_mat [word-1:0];
	wire [d-1:0] a_and_bc_mat [word-1:0];
	wire [d-1:0] b_and_c_mat [word-1:0];
	wire [d-1:0] bc_reg_mat [word-1:0];

	for(k=0; k<d; k=k+1) begin: kgen
		for(j=0; j<word; j=j+1) begin: jgen
			assign a_input_mat[j][k] = a_input[j*d+k];			
			assign bc_reg_mat[j][k] = b_xor_c_reg[j*d+k];
			
			assign b_reg_mat[j][k] = b_reg[j*d+k];
			assign c_input_mat[j][k] = c_input[j*d+k];
			
			assign b_and_c[j*d+k] = b_and_c_mat[j][k];
			assign a_and_bc[j*d+k] = a_and_bc_mat[j][k];
		end
	end


	genvar i;
	generate
		for (i = 0; i < word; i = i + 1) begin : block
			MSKand_HPC2 #(
			.d(d)
			) MSKand_HPC2_instance_a_bc (
				.ina(bc_reg_mat[i]),
				.inb(a_input_mat[i]),
				.rnd(rnd_a_and_bc[and_pini_nrnd*(i+1)-1:and_pini_nrnd*i]),
				.clk(clk),
				.out_c(a_and_bc_mat[i])
			);

			MSKand_HPC2 #(
			.d(d)
			) MSKand_HPC2_instance_bc (
				.ina(b_reg_mat[i]),
				.inb(c_input_mat[i]),
				.rnd(rnd_b_and_c[and_pini_nrnd*(i+1)-1:and_pini_nrnd*i]),
				.clk(clk),
				.out_c(b_and_c_mat[i])
			);
		end
	endgenerate

endmodule
