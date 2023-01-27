library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;
use work.interfaces_32_ska.all;

-- Calculates the zq encoding according to the NTRU paper.
-- This compresses 4 2-bit smasked mall elments into a single masked 1 byte word
entity encode_R3_msk is
	port(
		clock        : in  std_logic;
		reset        : in  std_logic;
		input        : in  t_shared(1 downto 0);
		input_valid  : in  std_logic;
		rnd_input    : in  std_logic_vector(and_pini_mul_nrnd * 4 - 1 downto 0);
		output       : out t_shared(7 downto 0);
		output_valid : out std_logic;
		done         : out std_logic
	);
end entity encode_R3_msk;

architecture RTL2 of encode_R3_msk is

	signal counter : integer range 0 to p / 4;

	signal shift_reg : t_shared(7 downto 0);

	signal input_plus_one : t_shared(1 downto 0);

	type type_state is (first, second, third, fourth, final);
	signal state : type_state;

	signal a_input_flat : std_logic_vector(shares * 2 - 1 downto 0);
	signal b_input_flat : std_logic_vector(shares * 2 - 1 downto 0);
	signal b_input      : t_shared(1 downto 0);

	signal rnd : std_logic_vector(and_pini_mul_nrnd * 4 - 1 downto 0);

	signal out_c : std_logic_vector(shares * 3 - 1 downto 0);

	signal input_valid_pipe : std_logic_vector(3 downto 0);

begin
	fsm_process : process(clock, reset) is
	begin
		if reset = '1' then
			state        <= first;
			counter      <= 0;
			output_valid <= '0';
			done         <= '0';
		elsif rising_edge(clock) then
			case state is
				when first =>
					if input_valid_pipe(3) = '1' then
						state     <= second;
						shift_reg <= input_plus_one & shift_reg(7 downto 2);
					end if;
					output_valid <= '0';
					done         <= '0';
				when second =>
					if input_valid_pipe(3) = '1' then
						state     <= third;
						shift_reg <= input_plus_one & shift_reg(7 downto 2);
					end if;
				when third =>
					if input_valid_pipe(3) = '1' then
						state     <= fourth;
						shift_reg <= input_plus_one & shift_reg(7 downto 2);
					end if;
				when fourth =>
					if input_valid_pipe(3) = '1' then
						counter <= counter + 1;
						if counter + 1 = p / 4 then
							state <= final;
						else
							state <= first;
						end if;

						shift_reg <= input_plus_one & shift_reg(7 downto 2);

						output_valid <= '1';
					end if;
				when final =>
					state                 <= first;
					shift_reg(1 downto 0) <= input_plus_one;
					shift_reg(7 downto 2) <= (others => (others => '0'));
					output_valid          <= '1';
					done                  <= '1';
					counter               <= 0;
			end case;
		end if;
	end process fsm_process;

	input_valid_pipe <= input_valid_pipe(2 downto 0) & input_valid when rising_edge(clock);

	output <= shift_reg;

	rnd          <= rnd_input;
	a_input_flat <= t_shared_flatten(input, 2);

	-- Set b input to a masked "01"
	b_input(1)                      <= ((others => '0'));
	b_input(0)(0)                   <= '1';
	b_input(0)(shares - 1 downto 1) <= (others => '0');

	b_input_flat <= t_shared_flatten(b_input, 2);

	adder_2bit_inst : entity work.adder_2bit
		generic map(
			d => shares
		)
		port map(
			clk     => clock,
			a_input => a_input_flat,
			b_input => b_input_flat,
			rnd     => rnd,
			out_c   => out_c
		);

	input_plus_one <= t_shared_pack(out_c, 3)(1 downto 0);

end architecture RTL2;
