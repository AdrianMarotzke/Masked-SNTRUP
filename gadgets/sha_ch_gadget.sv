module sha_ch_gadget #(parameter d=2, parameter word=13) (
	clk,
	e_input,
	f_input,
	g_input,
	rnd,
	out_ch
);

	localparam and_pini_mul_nrnd = d*(d-1)/2;
	localparam and_pini_nrnd = and_pini_mul_nrnd;

	input  clk;
	input  [d*word-1:0] e_input;
	input  [d*word-1:0] f_input;
	input  [d*word-1:0] g_input;
	input  [and_pini_nrnd*word-1:0] rnd;
	output [d*word-1:0] out_ch;


	wire [d*word-1:0] e_and_fg;
	wire [d*word-1:0] f_xor_g;
	wire [d*word-1:0] f_xor_g_reg;
	wire [d*word-1:0] g_reg1;
	wire [d*word-1:0] g_reg2;
	wire [and_pini_nrnd*word-1:0] rnd_e_and_fg;


	assign rnd_e_and_fg = rnd[and_pini_nrnd*word-1:0];

	MSKreg #(
	.d(d),
	.count(word)
	) MSKreg_instance (
		.clk(clk),
		.in_a(f_xor_g),
		.out_a(f_xor_g_reg)
	);

	MSKreg #(
		.d(d),
		.count(word)
	) MSKreg_instance_g1 (
		.clk(clk),
		.in_a(g_input),
		.out_a(g_reg1)
	);
	MSKreg #(
		.d(d),
		.count(word)
	) MSKreg_instance_g2 (
		.clk(clk),
		.in_a(g_reg1),
		.out_a(g_reg2)
	);
	
	MSKxor #(
	.d(d),
	.count(word)
	) MSKxor_instance (
		.ina(g_reg2),
		.inb(e_and_fg),
		.out_c(out_ch)
	);

	MSKxor #(
		.d(d),
		.count(word)
	) MSKxor_instance_fg (
		.ina(g_input),
		.inb(f_input),
		.out_c(f_xor_g)
	);
	// unpack vector to matrix --> easier for handling
	genvar k,j;

	wire [d-1:0] e_input_mat [word-1:0];
	wire [d-1:0] e_and_fg_mat [word-1:0];

	wire [d-1:0] fg_reg_mat [word-1:0];
	
	for(k=0; k<d; k=k+1) begin: kgen
		for(j=0; j<word; j=j+1) begin: jgen
			assign e_input_mat[j][k] = e_input[j*d+k];

			assign fg_reg_mat[j][k] = f_xor_g_reg[j*d+k];
			
			assign e_and_fg[j*d+k] = e_and_fg_mat[j][k];
		end
	end


	genvar i;
	generate
		for (i = 0; i < word; i = i + 1) begin : block
			MSKand_HPC2 #(
			.d(d)
			) MSKand_HPC2_instance_e_fg (
				.ina(fg_reg_mat[i]),
				.inb(e_input_mat[i]),
				.rnd(rnd_e_and_fg[and_pini_nrnd*(i+1)-1:and_pini_nrnd*i]),
				.clk(clk),
				.out_c(e_and_fg_mat[i])
			);
		end
	endgenerate

endmodule
