library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;
use work.interfaces_32_ska.all;

entity rq_mult_msk is
	port(
		clock              : in  std_logic;
		reset              : in  std_logic;
		start_mult         : in  std_logic;
		mult_input_address : out std_logic_vector(p_num_bits - 1 downto 0);
		mult_input         : in  t_shared(1 downto 0);
		output             : out t_shared(q_num_bits - 1 downto 0);
		output_greater_0   : out t_shared(0 downto 0);
		output_valid       : out std_logic;
		done               : out std_logic;
		rnd_input          : in  std_logic_vector(level_rand_requirement * 2 + and_pini_mul_nrnd * q_num_bits * 3 - 1 downto 0);
		load_array_start   : in  std_logic;
		load_array_address : out std_logic_vector(p_num_bits - 1 downto 0);
		load_array_input   : in  std_logic_vector(q_num_bits - 1 downto 0) -- this is a public variable (either public key or ciphertext)
	);
end entity rq_mult_msk;

architecture RTL of rq_mult_msk is
	type state_type is (IDLE, LOAD_ARRAY, LOAD_ARRAY_FINAL, MULT_STATE, MULT_STATE_ROTATE, OUTPUT_STATE_WAIT, OUTPUT_STATE);
	signal state_rq_mult : state_type;

	constant add_delay     : integer := 10;
	constant mux3_delay    : integer := 3;
	constant mux2_delay    : integer := 2;
	constant add_mux_delay : integer := add_delay * 2 + mux3_delay + mux2_delay;

	signal counter        : integer range 0 to p;
	signal counter2       : integer range 0 to p;
	signal counter2_delay : integer range 0 to p;

	signal ram_address : std_logic_vector(p_num_bits - 1 downto 0);
	signal ram_write   : std_logic;
	signal ram_data_in : std_logic_vector(q_num_bits - 1 downto 0);

	signal ram_address_b       : std_logic_vector(p_num_bits - 1 downto 0);
	signal ram_address_b_delay : std_logic_vector(p_num_bits - 1 downto 0);
	signal ram_data_out        : std_logic_vector(q_num_bits - 1 downto 0);

	signal array_address     : std_logic_vector(p_num_bits - 1 downto 0);
	signal array_address_fsm : std_logic_vector(p_num_bits - 1 downto 0);
	signal array_write       : std_logic;
	signal array_write_fsm   : std_logic;
	signal array_data_in     : t_shared(q_num_bits - 1 downto 0);
	signal array_data_out    : t_shared(q_num_bits - 1 downto 0);

	signal array_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal array_data_out_b : t_shared(q_num_bits - 1 downto 0);

	signal array_write_pipe : std_logic_vector(add_mux_delay - 1 downto 0);

	type type_address_pipe is array (add_mux_delay - 1 downto 0) of std_logic_vector(p_num_bits - 1 downto 0);

	signal array_address_pipe : type_address_pipe;

	signal ram_write_pipe   : std_logic;
	signal ram_address_pipe : std_logic_vector(p_num_bits - 1 downto 0);

	type type_rq_pipe is array (natural range <>) of t_shared(q_num_bits - 1 downto 0);

	signal ram_data_in_pipe : std_logic_vector(q_num_bits - 1 downto 0);

	signal ram_data_0_store        : std_logic_vector(q_num_bits - 1 downto 0);
	signal ram_data_0_store_pipe   : std_logic_vector(q_num_bits - 1 downto 0);
	signal ram_data_0_store_enable : std_logic;

	signal ram_data_tap_addition      : std_logic_vector(q_num_bits downto 0);
	signal ram_data_tap_addition_q    : std_logic_vector(q_num_bits downto 0);
	signal ram_data_tap_addition_modq : std_logic_vector(q_num_bits - 1 downto 0);

	signal ram_data_out_pipe : std_logic_vector(q_num_bits - 1 downto 0);

	constant masked_one_v : std_logic_vector(2 * shares - 1 downto 0) := std_logic_vector(to_unsigned(1, 2 * shares)); --(others => 'X'); --
	constant masked_one   : t_shared(2 - 1 downto 0)                  := t_shared_pack(masked_one_v, 2);

	signal load_array_pipe : std_logic;

	signal output_valid_pipe : std_logic_vector(add_delay + 1 downto 0);

	signal rq_trans : t_shared_trans;
	signal rq_flat  : std_logic_vector(shares * q_num_bits - 1 downto 0);

	signal q_sub_rq_trans : t_shared_trans;
	signal q_sub_rq_flat  : std_logic_vector(shares * q_num_bits - 1 downto 0);

	signal mult_input_flat : std_logic_vector(shares * 2 - 1 downto 0);

	signal mux3_rnd_in : std_logic_vector(and_pini_nrnd * q_num_bits * 2 - 1 downto 0);
	signal out_mux3    : std_logic_vector(shares * q_num_bits - 1 downto 0);

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
begin

	process(clock, reset) is
	begin
		if reset = '1' then
			state_rq_mult <= IDLE;
		elsif rising_edge(clock) then
			case state_rq_mult is
				when IDLE =>
					counter              <= 0;
					counter2             <= 0;
					done                 <= '0';
					output_valid_pipe(0) <= '0';
					
					if load_array_start = '1' then
						state_rq_mult <= LOAD_ARRAY;
						counter       <= p - 1;
					end if;

					if start_mult = '1' then
						state_rq_mult <= MULT_STATE;

						--counter  <= counter + 1;
						counter2 <= counter2 + 1;
					end if;

					ram_write_pipe  <= '0';
					array_write_fsm <= '0';

					array_write_pipe(0) <= '0';
					load_array_pipe     <= '0';
				when LOAD_ARRAY =>
					counter <= counter - 1;

					if counter = 0 then
						state_rq_mult <= LOAD_ARRAY_FINAL;
						counter       <= 0;
					end if;

					ram_address_pipe <= std_logic_vector(to_unsigned(p - 1 - counter, p_num_bits));
					ram_write_pipe   <= '1';
					ram_data_in_pipe <= load_array_input;

					array_address_fsm <= std_logic_vector(to_unsigned(counter, p_num_bits));
					array_write_fsm   <= '1';

					--array_data_in <= (others => (others => '0'));

					load_array_pipe <= '1';
				when LOAD_ARRAY_FINAL =>
					ram_write_pipe   <= '0';
					ram_data_in_pipe <= load_array_input;

					array_write_fsm <= '0';

					state_rq_mult <= IDLE;
				when MULT_STATE =>
					array_write_pipe(0) <= '1';

					array_address_pipe(0) <= std_logic_vector(to_unsigned(counter2_delay, p_num_bits));
					ram_address_pipe      <= ram_address_b_delay;

					if counter2 = p - 1 then
						--array_write_pipe(0) <= '0';
						state_rq_mult <= MULT_STATE;
						counter       <= counter + 1;
						counter2      <= 0;
					else
						counter2 <= counter2 + 1;
					end if;

					if counter = p then
						state_rq_mult <= OUTPUT_STATE_WAIT;
						counter2      <= 0;
					end if;

					load_array_pipe <= '0';

					ram_data_in_pipe <= ram_data_out;

					ram_write_pipe <= '1';
				when MULT_STATE_ROTATE =>
					state_rq_mult <= MULT_STATE;
					counter       <= counter + 1;
					counter2      <= 0;

					--array_data_in       <= out_mul3_t_shared;
					array_write_pipe(0) <= '1';

					array_address_pipe(0) <= std_logic_vector(to_unsigned(counter2_delay, p_num_bits));
					ram_address_pipe      <= ram_address_b_delay;
				when OUTPUT_STATE_WAIT =>
					array_write_pipe(0) <= '0';
					if array_write = '0' then
						state_rq_mult <= OUTPUT_STATE;
					end if;

					ram_write_pipe <= '0';
				when OUTPUT_STATE =>
					output_valid_pipe(0) <= '1';
					array_write_pipe(0)  <= '0';

					counter2 <= counter2 + 1;

					if counter2 = p then
						counter2             <= counter2;
						output_valid_pipe(0) <= '0';

						if output_valid_pipe(add_delay) = '0' then
							state_rq_mult <= IDLE;
							done          <= '1';
							counter2      <= 0;
							counter       <= 0;
						end if;

						--output_valid  <= '0';
					end if;
			end case;

			------ Some other clock logic

			array_write_pipe(add_mux_delay - 1 downto 1)   <= array_write_pipe(add_mux_delay - 2 downto 0);
			array_address_pipe(add_mux_delay - 1 downto 1) <= array_address_pipe(add_mux_delay - 2 downto 0);

			counter2_delay <= counter2;

			ram_address_b_delay <= ram_address_b;

			ram_data_0_store_enable <= '0';

			ram_data_out_pipe     <= ram_data_out;
			--ram_data_0_store(mul3_delay - 1 downto 1) <= ram_data_0_store(mul3_delay - 2 downto 0);
			ram_data_0_store_pipe <= ram_data_0_store;

			if ram_address_b_delay = std_logic_vector(to_unsigned(0, p_num_bits)) then
				ram_data_0_store        <= ram_data_out;
				ram_data_0_store_enable <= '1';
			end if;

			array_data_out_b_pipe(add_delay * 2 - 1 downto 1) <= array_data_out_b_pipe(add_delay * 2 - 2 downto 0);
			array_data_out_b_pipe(0)                          <= array_data_out_b;

			adder_out_pipe(add_delay - 1 downto 1) <= adder_out_pipe(add_delay - 2 downto 0);
			adder_out_pipe(0)                      <= adder_output(q_num_bits - 1 downto 0);
		end if;
	end process;

	output_valid                              <= output_valid_pipe(add_delay);
	output_valid_pipe(add_delay + 1 downto 1) <= output_valid_pipe(add_delay downto 0) when rising_edge(clock);

	adder_rand_in <= rnd_input(level_rand_requirement - 1 downto 0);
	sub_q_rand_in <= rnd_input(level_rand_requirement * 2 - 1 downto level_rand_requirement);
	mux3_rnd_in   <= rnd_input(level_rand_requirement * 2 + and_pini_mul_nrnd * q_num_bits * 2 - 1 downto level_rand_requirement * 2);
	mux2_rnd_in   <= rnd_input(level_rand_requirement * 2 + and_pini_mul_nrnd * q_num_bits * 3 - 1 downto level_rand_requirement * 2 + and_pini_mul_nrnd * q_num_bits * 2);

	array_data_in <= (others => (others => '0')) when state_rq_mult = LOAD_ARRAY or state_rq_mult = LOAD_ARRAY_FINAL else out_mux2_pack;

	load_array_address <= std_logic_vector(to_unsigned(counter, p_num_bits)) when state_rq_mult = LOAD_ARRAY else (others => '0');
	mult_input_address <= std_logic_vector(to_unsigned(counter, p_num_bits)) when state_rq_mult = MULT_STATE else (others => '0');

	ram_address_b   <= std_logic_vector(to_unsigned(counter2, p_num_bits));
	array_address_b <= std_logic_vector(to_unsigned(counter2, p_num_bits));

	--out_mul3_t_shared <= t_shared_pack(out_mul3, q_num_bits);

	array_write   <= array_write_fsm when state_rq_mult /= MULT_STATE and state_rq_mult /= OUTPUT_STATE and state_rq_mult /= OUTPUT_STATE_WAIT else array_write_pipe(add_mux_delay - 1);
	array_address <= array_address_fsm when state_rq_mult /= MULT_STATE and state_rq_mult /= OUTPUT_STATE and state_rq_mult /= OUTPUT_STATE_WAIT else array_address_pipe(add_mux_delay - 1);

	ram_write   <= ram_write_pipe when rising_edge(clock);
	ram_address <= ram_address_pipe when rising_edge(clock);
	ram_data_in <= ram_data_in_pipe when (load_array_pipe = '1')
	               else ram_data_tap_addition_modq when (unsigned(ram_address) = p - 2)
	               else ram_data_0_store_pipe when (unsigned(ram_address) = p - 1)
	               else ram_data_in_pipe;

	ram_data_tap_addition   <= std_logic_vector(resize(unsigned(ram_data_out_pipe), q_num_bits + 1) + unsigned(ram_data_0_store_pipe));
	ram_data_tap_addition_q <= std_logic_vector(unsigned(ram_data_tap_addition) - q);

	ram_data_tap_addition_modq <= ram_data_tap_addition(q_num_bits - 1 downto 0) when unsigned(ram_data_tap_addition) <= q else ram_data_tap_addition_q(q_num_bits - 1 downto 0);

	output              <= array_data_out_b_pipe(add_delay - 1) when output_valid_pipe(add_delay) = '1' else (others => (others => '0'));
	output_greater_0(0) <= sub_q_output(q_num_bits) when output_valid_pipe(add_delay) = '1' else (others => '0');

	rq_trans(0)       <= std_logic_vector(resize(unsigned(ram_data_out), 14)) when state_rq_mult = MULT_STATE or state_rq_mult = OUTPUT_STATE_WAIT else (others => '0');
	q_sub_rq_trans(0) <= std_logic_vector(resize(q - unsigned(ram_data_out), 14)) when state_rq_mult = MULT_STATE or state_rq_mult = OUTPUT_STATE_WAIT else (others => '0');

	zero_dummy_msk : for i in 1 to shares - 1 generate
		rq_trans(i)        <= (others => '0');
		q_sub_rq_trans(i)  <= (others => '0');
		sub_q_dummy_msk(i) <= (others => '0');
	end generate zero_dummy_msk;

	rq_flat       <= t_shared_flatten(t_shared_trans_to_t_shared(rq_trans)(q_num_bits - 1 downto 0), q_num_bits);
	q_sub_rq_flat <= t_shared_flatten(t_shared_trans_to_t_shared(q_sub_rq_trans)(q_num_bits - 1 downto 0), q_num_bits);

	mult_input_flat <= t_shared_flatten(mult_input, 2) when state_rq_mult = MULT_STATE or state_rq_mult = OUTPUT_STATE_WAIT else (others => '0');

	mux3_gadget_inst : entity work.mux3_gadget
		generic map(
			d    => shares,
			word => q_num_bits
		)
		port map(
			clk     => clock,
			a_input => q_sub_rq_flat,
			b_input => rq_flat,
			s_input => mult_input_flat,
			rnd     => mux3_rnd_in,
			out_mux => out_mux3
		);

	adder_input_a(q_num_bits - 1 downto 0) <= t_shared_pack(out_mux3, q_num_bits);

	--	expand_array_t_shared : for i in 0 to 12 generate
	--		adder_input_b(i) <= array_data_out_b(i);
	--	end generate expand_array_t_shared;

	adder_input_b(q_num_bits - 1 downto 0) <= array_data_out_b_pipe(mux3_delay - 1);

	adder_input_a(13) <= (others => '0');
	adder_input_b(13) <= (others => '0');

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

	-- During multiplication, q is substracted when needed from the array. During the output, (q-1)/2 is substracted in order to determine if the output would have 
	-- been negative if the signed representation was used, this is needed for the modulo 3 calculation.
	sub_q_dummy_msk(0) <= std_logic_vector((NOT to_unsigned(q, 14)) + 1) when state_rq_mult /= OUTPUT_STATE else std_logic_vector((NOT to_unsigned(q12, 14)) + 1);

	sub_q_input_a(q_num_bits - 1 downto 0) <= adder_output(q_num_bits - 1 downto 0) when state_rq_mult /= OUTPUT_STATE else array_data_out_b;
	sub_q_input_a(13)                      <= adder_output(13) when state_rq_mult /= OUTPUT_STATE else (others => '0');

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

	rq_ram_inst : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => q_num_bits,
			DUAL_PORT     => true
		)
		port map(
			clock      => clock,
			address_a  => ram_address,
			write_a    => ram_write,
			data_in_a  => ram_data_in,
			data_out_a => open,
			address_b  => ram_address_b,
			write_b    => '0',
			data_in_b  => (others => '0'),
			data_out_b => ram_data_out
		);

	array_ram : entity work.ram_msk
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => q_num_bits
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
