// Masked NOT gate
module MSKinv #(parameter d=2, parameter count=1) (in_a, out_a);

	input  [count*d-1:0] in_a;
	output [count*d-1:0] out_a;

	genvar i;
	generate
		for(i=0; i<count; i=i+1) begin: inv
			assign out_a[i*d] = ~in_a[i*d];
			if (d > 1) begin
				assign out_a[i*d+1 +: d-1] = in_a[i*d+1 +: d-1];
			end
		end
	endgenerate

endmodule
