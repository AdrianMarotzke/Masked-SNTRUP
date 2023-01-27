module MSKor_HPC2 #(parameter d=2) (ina, inb, rnd, clk, out_c);

	localparam and_pini_mul_nrnd = d*(d-1)/2;
	localparam and_pini_nrnd = and_pini_mul_nrnd;

	input clk;
	input  [d-1:0] ina;
	input  [d-1:0] inb;
	input [and_pini_nrnd-1:0] rnd;
	output [d-1:0] out_c;
	
	wire [d-1:0] inv_ina;
	wire [d-1:0] inv_inb;
	wire [d-1:0] inv_out;
	

	MSKinv #(
		.d(d),
		.count(1)
	) MSKinv_instance_a (
		.in_a(ina),
		.out_a(inv_ina)
	);
	MSKinv #(
		.d(d),
		.count(1)
	) MSKinv_instance_b (
		.in_a(inb),
		.out_a(inv_inb)
	);
	
	
	MSKand_HPC2 #(
		.d(d)
	) MSKand_HPC2_instance (
		.ina(inv_ina),
		.inb(inv_inb),
		.rnd(rnd),
		.clk(clk),
		.out_c(inv_out)
	);
	
	MSKinv #(
		.d(d),
		.count(1)
	) MSKinv_instance_out (
		.in_a(inv_out),
		.out_a(out_c)
	);
endmodule