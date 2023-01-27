module barrett ( clk, dividend, m0, m0_inverse, quotient, remainder ) ;

	parameter M0LEN = 14;
	parameter SHIFT = 27;

	localparam M0LEN2 = M0LEN * 2;

	input  wire                     clk;
	input  wire [M0LEN2-1:0]        dividend;
	input  wire [M0LEN-1:0]         m0;
	input  wire [SHIFT-1:0]         m0_inverse;
	output wire [M0LEN-1:0]         quotient;
	output wire [M0LEN-1:0]         remainder;

	reg         [SHIFT-1:0]         m0_inverse_relay0;
	reg         [M0LEN2-1:0]        dividend_relay0;
	reg         [M0LEN2-1:0]        dividend_relay1;
	reg         [M0LEN2-1:0]        dividend_relay2;

	reg        [M0LEN2+SHIFT-1:0]  quo2;
	reg       [M0LEN2+SHIFT-1:0]    q0;
	reg         [M0LEN-1:0]         q0_relay;
	reg         [M0LEN-1:0]         r0;

	reg         [M0LEN-1:0]         m0_relay0;
	reg         [M0LEN-1:0]         m0_relay1;
	reg         [M0LEN-1:0]         m0_relay2;
	reg         [M0LEN-1:0]         m0_relay3;

	wire        [M0LEN-1:0]         q1;
	wire        [M0LEN:0]           r1;

	//assign 

	always @ (posedge clk) begin
		m0_inverse_relay0 <= m0_inverse;
		dividend_relay0 <= dividend;
		m0_relay0 <= m0;
	end

	always @ (posedge clk) begin
		quo2 <= dividend_relay0 * m0_inverse_relay0;
		dividend_relay1 <= dividend_relay0;
		dividend_relay2 <= dividend_relay1;
		m0_relay1 <= m0_relay0;
		m0_relay2 <= m0_relay1;
		m0_relay3 <= m0_relay2;
		q0 <= quo2;
	end


	always @ (posedge clk) begin
		r0 <= dividend_relay2 -  q0[SHIFT +: M0LEN]*m0_relay2;
		q0_relay <= q0[SHIFT +: M0LEN];
	end

	assign q1 = q0_relay + { { (M0LEN - 1) {1'b0} }, {1'b1} };
	assign r1 = { 1'b0, r0 } - { 1'b0, m0_relay3 };

	assign quotient = r1[M0LEN] ? q0_relay : q1;
	assign remainder = r1[M0LEN] ? r0 : r1[M0LEN-1:0];

endmodule

