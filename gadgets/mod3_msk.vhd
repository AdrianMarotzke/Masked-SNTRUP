library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;

-- Rounds the input, and takes the signed to unsigned conversion into account
-- TODO this can be shared with renecryption for rounding
entity mod3_msk is
	port(
		clock           : in  std_logic;
		reset           : in  std_logic;
		mod3_input      : in  t_shared(q_num_bits - 1 downto 0);
		input_greater_0 : in  t_shared(0 downto 0);
		rnd_input       : in  std_logic_vector(and_pini_mul_nrnd * (46) - 1 downto 0);
		mod3_output     : out t_shared(1 downto 0)
	);
end entity mod3_msk;

architecture RTL of mod3_msk is

	signal mod3_input_flat  : std_logic_vector(q_num_bits * shares - 1 downto 0);
	signal mod3_rnd_input   : std_logic_vector(and_pini_mul_nrnd * 40 - 1 downto 0);
	signal mod3_output_flat : std_logic_vector(2 * shares - 1 downto 0);

	signal input_greater_0_flat  : std_logic_vector(shares - 1 downto 0);
	signal input_less_0_flat     : std_logic_vector(2 * shares - 1 downto 0);
	signal constant_one          : std_logic_vector(2 * shares - 1 downto 0);
	signal mod3_sub1_rnd_input   : std_logic_vector(and_pini_mul_nrnd * 6 - 1 downto 0);
	signal mod3_sub1_output_flat : std_logic_vector(2 * shares - 1 downto 0);

	constant mod3_delay : integer := 24;
	
	type type_t_shared_array is array (natural range <>) of t_shared(0 downto 0);
	signal output_greater_0_pipe : type_t_shared_array(mod3_delay - 1 downto 0);
	
	component MSKinv
		generic(
			d     : integer := shares;
			count : integer := 1
		);
		port(
			in_a  : in  std_logic_vector;
			out_a : out std_logic_vector
		);
	end component MSKinv;
begin

	mod3_gadget_inst : entity work.mod3_gadget
		generic map(
			d => shares
		)
		port map(
			clk     => clock,
			a_input => mod3_input_flat,
			rnd     => mod3_rnd_input,
			out_mod => mod3_output_flat
		);

	mod3_sub1_gadget_inst : entity work.mul3_gadget
		generic map(
			d => shares
		)
		port map(
			clk      => clock,
			e_input  => mod3_output_flat,
			v_input  => constant_one,
			a_input  => input_less_0_flat,
			rnd      => mod3_sub1_rnd_input,
			out_mul3 => mod3_sub1_output_flat
		);

	mod3_rnd_input      <= rnd_input(and_pini_mul_nrnd * 40 - 1 downto 0);
	mod3_sub1_rnd_input <= rnd_input(and_pini_mul_nrnd * 46 - 1 downto and_pini_mul_nrnd * 40);

	input_greater_0_flat <= t_shared_flatten(output_greater_0_pipe(mod3_delay-1), 1);
	mod3_input_flat <= t_shared_flatten(mod3_input, q_num_bits);

	output_greater_0_pipe <= output_greater_0_pipe(mod3_delay - 2 downto 0) & input_greater_0 when rising_edge(clock);
	
	inv_input_greater_0 : MSKinv
		generic map(
			d     => shares,
			count => 1
		)
		port map(input_greater_0_flat, input_less_0_flat(shares - 1 downto 0)); -- @suppress "Positional association should not be used, use named association instead"

	input_less_0_flat(2 * shares - 1 downto shares) <= input_less_0_flat(shares - 1 downto 0);

	mod3_output <= t_shared_pack(mod3_sub1_output_flat, 2);

	constant_one(0)                   <= '1';
	constant_one(2 * shares - 1 downto 1) <= (others => '0');
end architecture RTL;
