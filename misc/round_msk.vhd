library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;
use work.interfaces_32_ska.all;

entity round_msk is
	port(
		clock           : in  std_logic;
		reset           : in  std_logic;
		rand_input      : in  std_logic_vector(and_pini_nrnd * q_num_bits + level_rand_requirement * 2 + and_pini_mul_nrnd * 46 - 1 downto 0);
		input           : in  t_shared(q_num_bits - 1 downto 0);
		input_greater_0 : in  t_shared(0 downto 0);
		enable          : in  std_logic;
		output          : out signed(1 downto 0);
		output_rounded  : out t_shared(q_num_bits - 1 downto 0);
		output_valid    : out std_logic
	);
end entity round_msk;

architecture RTL of round_msk is

	constant add_delay  : integer := 10;
	constant mod3_delay : integer := 25 + 4;
	constant mux2_delay : integer := 2;

	constant round_delay : integer := add_delay * 2 + mod3_delay + mux2_delay;

	type type_rq_pipe is array (natural range <>) of t_shared(q_num_bits - 1 downto 0);

	signal mod3_output : t_shared(1 downto 0);
	signal mod3_output_1_neg : t_shared(0 downto 0);
	signal mod_rand_in : std_logic_vector(and_pini_mul_nrnd * (46) - 1 downto 0);

	signal xor_output : std_logic_vector(shares - 1 downto 0);
	signal input_pipe : type_rq_pipe(mod3_delay - 1 downto 0);

	signal adder_input_a : t_shared(width - 1 downto 0);
	signal adder_input_b : t_shared(width - 1 downto 0);
	signal adder_rand_in : std_logic_vector(level_rand_requirement - 1 downto 0);
	signal adder_output  : t_shared(width - 1 downto 0);

	signal sub_q_input_a : t_shared(width - 1 downto 0);
	signal sub_q_input_b : t_shared(width - 1 downto 0);
	signal sub_q_rand_in : std_logic_vector(level_rand_requirement - 1 downto 0);
	signal sub_q_output  : t_shared(width - 1 downto 0);

	signal sub_q_dummy_msk : t_shared_trans;

	signal sub_q_output_flatten : std_logic_vector(shares * q_num_bits - 1 downto 0);

	signal array_data_out_b_pipe : type_rq_pipe(add_delay * 2 - 1 downto 0);

	signal adder_out_pipe    : type_rq_pipe(add_delay - 1 downto 0);
	signal adder_out_flatten : std_logic_vector(shares * q_num_bits - 1 downto 0);

	signal mux2_select_flatten : std_logic_vector(shares - 1 downto 0);

	signal mux2_rnd_in   : std_logic_vector(and_pini_nrnd * q_num_bits - 1 downto 0);
	signal out_mux2      : std_logic_vector(shares * q_num_bits - 1 downto 0);
	signal out_mux2_pack : t_shared(q_num_bits - 1 downto 0);

	signal valid_pipe : std_logic_vector(round_delay - 1 downto 0);

	component MSKxor
		generic(
			d     : integer;
			count : integer
		);
		port(
			ina   : in  std_logic_vector;
			inb   : in  std_logic_vector;
			out_c : out std_logic_vector
		);
	end component MSKxor;

	signal input_e           : t_shared(q_num_bits - 1 downto 0);
	signal input_greater_0_e : t_shared(0 downto 0);
begin

	round_process : process(clock, reset) is
	begin
		if reset = '1' then

		elsif rising_edge(clock) then
			adder_out_pipe(add_delay - 1 downto 1) <= adder_out_pipe(add_delay - 2 downto 0);
			adder_out_pipe(0)                      <= adder_output(q_num_bits - 1 downto 0);

			input_pipe(mod3_delay - 1 downto 1) <= input_pipe(mod3_delay - 2 downto 0);
			input_pipe(0)                       <= input;
		end if;
	end process round_process;

	mod_rand_in   <= rand_input(and_pini_mul_nrnd * 46 - 1 downto 0);
	adder_rand_in <= rand_input(level_rand_requirement + and_pini_mul_nrnd * 46 - 1 downto and_pini_mul_nrnd * 46);
	sub_q_rand_in <= rand_input(level_rand_requirement * 2 + and_pini_mul_nrnd * 46 - 1 downto level_rand_requirement + and_pini_mul_nrnd * 46);
	mux2_rnd_in   <= rand_input(and_pini_nrnd * q_num_bits + level_rand_requirement * 2 + and_pini_mul_nrnd * 46 - 1 downto level_rand_requirement * 2 + and_pini_mul_nrnd * 46);

	input_e           <= input when enable = '1' else (others => (others => '0'));
	input_greater_0_e <= input_greater_0 when enable = '1' else (others => (others => '0'));

	mod3_msk_inst : entity work.mod3_msk
		port map(
			clock           => clock,
			reset           => reset,
			mod3_input      => input_e,
			input_greater_0 => input_greater_0_e,
			rnd_input       => mod_rand_in,
			mod3_output     => mod3_output
		);

	MSKxor_inst : component MSKxor
		generic map(
			d     => shares,
			count => 1
		)
		port map(
			ina   => mod3_output(0),
			inb   => mod3_output(1),
			out_c => xor_output
		);

	adder_input_a(q_num_bits - 1 downto 0) <= input_pipe(mod3_delay - 1);
	adder_input_a(13)                      <= (others => '0');

	adder_input_b(13) <= (others => '0');
	adder_input_b(12) <= xor_output;
	adder_input_b(11) <= (others => '0');
	adder_input_b(10) <= (others => '0');
	adder_input_b(9)  <= (others => '0');
	adder_input_b(8)  <= xor_output;
	adder_input_b(7)  <= xor_output;
	adder_input_b(6)  <= xor_output;
	adder_input_b(5)  <= xor_output;
	adder_input_b(4)  <= (others => '0');
	adder_input_b(3)  <= xor_output;
	adder_input_b(2)  <= xor_output;
	adder_input_b(1)  <= xor_output;
	adder_input_b(0)  <= mod3_output(1);

	ska_16_inst : entity work.ska_16
		generic map(
			width => width
		)
		port map(
			clk     => clock,
			A       => adder_input_a,
			B       => adder_input_b,
			rand_in => adder_rand_in,
			S       => adder_output
		);

	zero_dummy_msk : for i in 1 to shares - 1 generate
		sub_q_dummy_msk(i) <= (others => '0');
	end generate zero_dummy_msk;

	sub_q_dummy_msk(0) <= std_logic_vector((NOT to_unsigned(q, 14)) + 1); -- TODO correct! the 1 can maybe be removed!

	sub_q_input_a(q_num_bits - 1 downto 0) <= adder_output(q_num_bits - 1 downto 0);
	sub_q_input_a(13)                      <= adder_output(13);

	sub_q_input_b <= t_shared_trans_to_t_shared(sub_q_dummy_msk);

	ska_sub_q : entity work.ska_16
		generic map(
			width => width
		)
		port map(
			clk     => clock,
			A       => sub_q_input_a,
			B       => sub_q_input_b,
			rand_in => sub_q_rand_in,
			S       => sub_q_output
		);

	adder_out_flatten    <= t_shared_flatten(adder_out_pipe(add_delay - 1), q_num_bits);
	sub_q_output_flatten <= t_shared_flatten(sub_q_output(q_num_bits - 1 downto 0), q_num_bits);

	mux2_select_flatten <= sub_q_output(q_num_bits);

	mux2_gadget_inst : entity work.mux2_gadget
		generic map(
			d    => shares,
			word => q_num_bits
		)
		port map(
			clk     => clock,
			a_input => adder_out_flatten,
			b_input => sub_q_output_flatten,
			s_input => mux2_select_flatten,
			rnd     => mux2_rnd_in,
			out_mux => out_mux2
		);

	out_mux2_pack <= t_shared_pack(out_mux2, q_num_bits);

	output_rounded <= out_mux2_pack;

	valid_pipe(0) <= enable when rising_edge(clock);

	valid_pipe(round_delay - 1 downto 1) <= valid_pipe(round_delay - 2 downto 0) when rising_edge(clock);

	output_valid <= valid_pipe(round_delay - 1);
end architecture RTL;
