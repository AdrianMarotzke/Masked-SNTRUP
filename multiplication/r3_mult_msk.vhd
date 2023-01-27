library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;

entity r3_mult_msk is
	port(
		clock              : in  std_logic;
		reset              : in  std_logic;
		start_mult         : in  std_logic;
		mult_input_address : out std_logic_vector(p_num_bits - 1 downto 0);
		mult_input         : in  t_shared(1 downto 0);
		output             : out t_shared(1 downto 0);
		output_valid       : out std_logic;
		done               : out std_logic;
		rnd_input          : in  std_logic_vector(and_pini_mul_nrnd * 6 - 1 downto 0);
		load_array_start   : in  std_logic;
		load_array_address : out std_logic_vector(p_num_bits - 1 downto 0);
		load_array_input   : in  t_shared(1 downto 0)
	);
end entity r3_mult_msk;

architecture RTL of r3_mult_msk is
	type state_type is (IDLE, LOAD_ARRAY, LOAD_ARRAY_FINAL, MULT_STATE, MULT_STATE_ROTATE, MULT_STATE_ROTATE_2, OUTPUT_STATE);
	signal state_r3_mult : state_type;

	type small_array_type is array (p - 1 downto 0) of signed(1 downto 0);

	constant mul3_delay : integer := 5;

	signal counter        : integer range 0 to p;
	signal counter2       : integer range 0 to p;
	signal counter2_delay : integer range 0 to p;

	signal ram_address : std_logic_vector(p_num_bits - 1 downto 0);
	signal ram_write   : std_logic;
	signal ram_data_in : t_shared(2 - 1 downto 0);

	signal ram_address_b       : std_logic_vector(p_num_bits - 1 downto 0);
	signal ram_address_b_delay : std_logic_vector(p_num_bits - 1 downto 0);
	signal ram_data_out        : t_shared(2 - 1 downto 0);

	signal array_address     : std_logic_vector(p_num_bits - 1 downto 0);
	signal array_address_fsm : std_logic_vector(p_num_bits - 1 downto 0);
	signal array_write       : std_logic;
	signal array_write_fsm   : std_logic;
	signal array_data_in     : t_shared(2 - 1 downto 0);
	signal array_data_out    : t_shared(2 - 1 downto 0);

	signal array_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal array_write_b    : std_logic;
	signal array_data_in_b  : t_shared(2 - 1 downto 0);
	signal array_data_out_b : t_shared(2 - 1 downto 0);

	signal e_input  : std_logic_vector(shares * 2 - 1 downto 0);
	signal v_input  : std_logic_vector(shares * 2 - 1 downto 0);
	signal a_input  : std_logic_vector(shares * 2 - 1 downto 0);
	signal out_mul3 : std_logic_vector(shares * 2 - 1 downto 0);

	signal out_mul3_t_shared : t_shared(2 - 1 downto 0);

	signal rnd : std_logic_vector(and_pini_mul_nrnd * 6 - 1 downto 0);

	signal array_write_pipe : std_logic_vector(mul3_delay - 1 downto 0);

	type type_address_pipe is array (mul3_delay - 1 downto 0) of std_logic_vector(p_num_bits - 1 downto 0);

	signal array_address_pipe : type_address_pipe;

	signal ram_write_pipe   : std_logic_vector(mul3_delay - 1 downto 0);
	signal ram_address_pipe : type_address_pipe;

	type type_t_shared_pipe is array (mul3_delay - 1 downto 0) of t_shared(2 - 1 downto 0);

	signal ram_data_in_pipe : type_t_shared_pipe;

	signal ram_data_0_store        : type_t_shared_pipe;
	signal ram_data_0_store_enable : std_logic;

	constant masked_one_v : std_logic_vector(2 * shares - 1 downto 0) := std_logic_vector(to_unsigned(1, 2 * shares)); --(others => 'X'); --
	constant masked_one   : t_shared(2 - 1 downto 0)                  := t_shared_pack(masked_one_v, 2);

	signal load_array_pipe : std_logic_vector(mul3_delay - 1 downto 0);

	signal output_valid_pipe : std_logic;

begin

	process(clock, reset) is
	begin
		if reset = '1' then
			state_r3_mult     <= IDLE;
			output_valid_pipe <= '0';
		elsif rising_edge(clock) then
			case state_r3_mult is
				when IDLE =>
					counter           <= 0;
					done              <= '0';
					output_valid_pipe <= '0';
					if load_array_start = '1' then
						state_r3_mult <= LOAD_ARRAY;
						counter       <= p - 1;
					end if;

					if start_mult = '1' then
						state_r3_mult <= MULT_STATE;

						--counter  <= counter + 1;
						counter2 <= counter2 + 1;
					end if;

					ram_write_pipe(0) <= '0';
					array_write_fsm   <= '0';

					array_write_pipe(0) <= '0';
					load_array_pipe(0)  <= '0';
				when LOAD_ARRAY =>
					counter <= counter - 1;

					if counter = 0 then
						state_r3_mult <= LOAD_ARRAY_FINAL;
						counter       <= 0;
					end if;

					ram_address_pipe(0) <= std_logic_vector(to_unsigned(p - 1 - counter, p_num_bits));
					ram_write_pipe(0)   <= '1';
					ram_data_in_pipe(0) <= load_array_input;

					array_address_fsm <= std_logic_vector(to_unsigned(counter, p_num_bits));
					array_write_fsm   <= '1';

					--array_data_in <= (others => (others => '0'));

					load_array_pipe(0) <= '1';
				when LOAD_ARRAY_FINAL =>
					ram_write_pipe(0)   <= '0';
					ram_data_in_pipe(0) <= load_array_input;

					array_write_fsm <= '0';

					state_r3_mult <= IDLE;
				when MULT_STATE =>
					array_write_pipe(0) <= '1';

					array_address_pipe(0) <= std_logic_vector(to_unsigned(counter2_delay, p_num_bits));
					ram_address_pipe(0)   <= ram_address_b_delay;

					if counter2 = p - 1 then
						--array_write_pipe(0) <= '0';
						state_r3_mult <= MULT_STATE_ROTATE;
					else
						counter2 <= counter2 + 1;
					end if;

					if counter = p then
						state_r3_mult <= OUTPUT_STATE;
						counter2      <= 0;
					end if;

					load_array_pipe(0) <= '0';

					ram_data_in_pipe(0) <= ram_data_out;

					ram_write_pipe(0) <= '1';
				when MULT_STATE_ROTATE =>
					state_r3_mult <= MULT_STATE_ROTATE_2;
					counter       <= counter + 1;
					counter2      <= 0;

					--array_data_in       <= out_mul3_t_shared;
					array_write_pipe(0) <= '1';

					array_address_pipe(0) <= std_logic_vector(to_unsigned(counter2_delay, p_num_bits));
					ram_address_pipe(0)   <= ram_address_b_delay;

				when MULT_STATE_ROTATE_2 =>
					state_r3_mult <= MULT_STATE;
					counter2      <= counter2 + 1;

					--array_data_in       <= out_mul3_t_shared;
					array_write_pipe(0) <= '0';

					array_address_pipe(0) <= std_logic_vector(to_unsigned(counter2_delay, p_num_bits));
					ram_address_pipe(0)   <= std_logic_vector(to_unsigned(p - 2, p_num_bits));

				when OUTPUT_STATE =>
					output_valid_pipe <= '1';

					array_write_pipe(0) <= '0';
					counter2            <= counter2 + 1;

					if counter2 = p - 1 then
						state_r3_mult <= IDLE;
						done          <= '1';
						counter2      <= 0;
						--output_valid  <= '0';
					end if;
			end case;

			------ Some other clock logic

			array_write_pipe(mul3_delay - 1 downto 1)   <= array_write_pipe(mul3_delay - 2 downto 0);
			array_address_pipe(mul3_delay - 1 downto 1) <= array_address_pipe(mul3_delay - 2 downto 0);

			ram_write_pipe(mul3_delay - 1 downto 1)   <= ram_write_pipe(mul3_delay - 2 downto 0);
			ram_address_pipe(mul3_delay - 1 downto 1) <= ram_address_pipe(mul3_delay - 2 downto 0);
			ram_data_in_pipe(mul3_delay - 1 downto 1) <= ram_data_in_pipe(mul3_delay - 2 downto 0);

			load_array_pipe(mul3_delay - 1 downto 1) <= load_array_pipe(mul3_delay - 2 downto 0);

			counter2_delay <= counter2;

			ram_address_b_delay <= ram_address_b;

			ram_data_0_store_enable <= '0';

			ram_data_0_store(mul3_delay - 1 downto 1) <= ram_data_0_store(mul3_delay - 2 downto 0);

			if ram_address_b_delay = std_logic_vector(to_unsigned(0, p_num_bits)) then
				ram_data_0_store(0)     <= ram_data_out;
				ram_data_0_store_enable <= '1';
			end if;
		end if;
	end process;

	output_valid <= output_valid_pipe;
	rnd          <= rnd_input;

	array_data_in <= (others => (others => '0')) when state_r3_mult = LOAD_ARRAY or state_r3_mult = LOAD_ARRAY_FINAL else out_mul3_t_shared;

	load_array_address <= std_logic_vector(to_unsigned(counter, p_num_bits)) when state_r3_mult = LOAD_ARRAY else (others => '0');
	mult_input_address <= std_logic_vector(to_unsigned(counter, p_num_bits)) when state_r3_mult = MULT_STATE or state_r3_mult = MULT_STATE_ROTATE or state_r3_mult = MULT_STATE_ROTATE_2 else (others => '0');

	ram_address_b   <= std_logic_vector(to_unsigned(counter2, p_num_bits));
	array_address_b <= std_logic_vector(to_unsigned(counter2, p_num_bits));

	e_input <= t_shared_flatten(mult_input, 2) when state_r3_mult /= MULT_STATE_ROTATE_2 else masked_one_v;
	v_input <= t_shared_flatten(ram_data_out, 2);
	a_input <= t_shared_flatten(array_data_out_b, 2) when state_r3_mult /= MULT_STATE_ROTATE_2 else t_shared_flatten(ram_data_0_store(mul3_delay - 2), 2);

	out_mul3_t_shared <= t_shared_pack(out_mul3, 2);

	array_write   <= array_write_fsm when state_r3_mult /= MULT_STATE and state_r3_mult /= MULT_STATE_ROTATE and state_r3_mult /= MULT_STATE_ROTATE_2 else array_write_pipe(mul3_delay - 1);
	array_address <= array_address_fsm when state_r3_mult /= MULT_STATE and state_r3_mult /= MULT_STATE_ROTATE and state_r3_mult /= MULT_STATE_ROTATE_2 else array_address_pipe(mul3_delay - 1);

	ram_write   <= ram_write_pipe(mul3_delay - 1);
	ram_address <= ram_address_pipe(mul3_delay - 1);
	ram_data_in <= ram_data_in_pipe(mul3_delay - 2) when (load_array_pipe(mul3_delay - 1) = '1')
	               else out_mul3_t_shared when (unsigned(ram_address) = p - 2)
	               else ram_data_0_store(mul3_delay - 2) when (unsigned(ram_address) = p - 1)
	               else ram_data_in_pipe(mul3_delay - 2);

	output <= array_data_out_b when output_valid_pipe = '1' else (others => (others => '0'));

	mul3_gadget_inst : entity work.mul3_gadget
		generic map(
			d => shares
		)
		port map(
			clk      => clock,
			e_input  => e_input,
			v_input  => v_input,
			a_input  => a_input,
			rnd      => rnd,
			out_mul3 => out_mul3
		);

	ram_msk_inst : entity work.ram_msk
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => 2
		)
		port map(
			clock      => clock,
			address_a  => ram_address,
			write_a    => ram_write,
			data_in_a  => ram_data_in,
			data_out_a => open,
			address_b  => ram_address_b,
			write_b    => '0',
			data_in_b  => (others => (others => '0')),
			data_out_b => ram_data_out
		);

	array_ram : entity work.ram_msk
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => 2
		)
		port map(
			clock      => clock,
			address_a  => array_address,
			write_a    => array_write,
			data_in_a  => array_data_in,
			data_out_a => array_data_out,
			address_b  => array_address_b,
			write_b    => '0',
			data_in_b  => (others => (others => '0')),
			data_out_b => array_data_out_b
		);

end architecture RTL;
