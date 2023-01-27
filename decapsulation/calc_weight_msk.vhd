library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;
use work.interfaces_32_ska.all;

-- Calculates if the weight of the a small polynomails equals w. If weight is equal to w, the mask_output is a masked 0.
-- Otherswise, mask output is a masked 1

entity calc_weight_msk is
	port(
		clock             : in  std_logic;
		reset             : in  std_logic;
		start             : in  std_logic;
		input             : in  t_shared(1 downto 0);
		input_address     : out std_logic_vector(p_num_bits - 1 downto 0);
		rand_in           : in  std_logic_vector(level_rand_requirement + and_pini_nrnd * 10 - 1 downto 0);
		mask_output       : out t_shared(0 downto 0);
		mask_output_valid : out std_logic
	);
end entity calc_weight_msk;

architecture RTL of calc_weight_msk is

	type state_type is (idle, new_input, wait_adder, adder_done, mask_weight, done_state);
	signal state_calc_weight : state_type;

	constant add_delay : integer := 10;

	constant or_delay : integer := 11;

	signal counter : integer range 0 to p;

	signal counter_delay : integer range 0 to add_delay * 2;

	signal A : t_shared(q_num_bits downto 0);
	signal B : t_shared(q_num_bits downto 0);
	signal S : t_shared(q_num_bits downto 0);

	signal weight : t_shared(q_num_bits downto 0);

	signal rand_compare : std_logic_vector(and_pini_nrnd * 10 - 1 downto 0);
	signal a_input      : std_logic_vector(shares * 10 - 1 downto 0);
	signal b_input      : std_logic_vector(shares * 10 - 1 downto 0);
	signal out_equal    : std_logic_vector(shares - 1 downto 0);

	signal weight_constant_trans : t_shared_trans;
	signal weight_constant       : t_shared(width - 1 downto 0);
begin

	fsm_process : process(clock, reset) is
	begin
		if reset = '1' then
			state_calc_weight <= idle;
			mask_output_valid <= '0';
		elsif rising_edge(clock) then
			case state_calc_weight is
				when idle =>
					if start = '1' then
						state_calc_weight <= new_input;
					end if;
					counter           <= 0;
					counter_delay     <= 0;
					mask_output_valid <= '0';
					input_address     <= (others => '0');
					weight            <= (others => (others => '0'));
				when new_input =>
					state_calc_weight      <= wait_adder;
					A                      <= weight;
					B(q_num_bits downto 1) <= (others => (others => '0'));
					B(0)                   <= input(0);
				when wait_adder =>
					counter_delay <= counter_delay + 1;
					if counter_delay = add_delay - 1 then
						state_calc_weight <= adder_done;
						counter           <= counter + 1;
						input_address     <= std_logic_vector(to_unsigned(counter + 1, p_num_bits));
					end if;
				when adder_done =>
					state_calc_weight <= new_input;
					weight            <= S;
					counter_delay     <= 0;
					if counter = p then
						state_calc_weight <= mask_weight;
					end if;
				when mask_weight =>
					counter_delay <= counter_delay + 1;
					if counter_delay = or_delay - 1 then
						state_calc_weight <= done_state;
					end if;
				when done_state =>
					mask_output(0)    <= out_equal;
					mask_output_valid <= '1';
					state_calc_weight <= idle;
			end case;
		end if;
	end process fsm_process;

	rand_compare <= rand_in(and_pini_nrnd * 10 - 1 + level_rand_requirement downto level_rand_requirement);

	ska_16_inst : entity work.ska_16
		generic map(
			width => 14
		)
		port map(
			clk     => clock,
			A       => A,
			B       => B,
			rand_in => rand_in(level_rand_requirement - 1 downto 0),
			S       => S
		);

	a_input <= t_shared_flatten(weight(9 downto 0), 10) when state_calc_weight = mask_weight else (others => '0');

	weight_constant_trans(0)                   <= std_logic_vector(to_unsigned(2 * t, width));
	weight_constant_trans(shares - 1 downto 1) <= (others => (others => '0'));

	weight_constant <= t_shared_trans_to_t_shared(weight_constant_trans);

	b_input <= t_shared_flatten(weight_constant(9 downto 0), 10) when state_calc_weight = mask_weight else (others => '0');

	compare_weight_inst : entity work.compare_weight
		generic map(
			d => shares
		)
		port map(
			clk       => clock,
			a_input   => a_input,
			b_input   => b_input,
			rnd       => rand_compare,
			out_equal => out_equal
		);

end architecture RTL;
