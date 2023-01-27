library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;
use work.interfaces_32_ska.all;

-- The core decryption
entity decryption_msk is
	port(
		clock         : in  std_logic;
		reset         : in  std_logic;
		start         : in  std_logic;
		done          : out std_logic;
		rnd_input     : in  std_logic_vector(and_pini_mul_nrnd * 46 + and_pini_nrnd * 6 + and_pini_nrnd * 2 + level_rand_requirement + and_pini_nrnd * 10 - 1 downto 0);
		output        : out t_shared(1 downto 0);
		output_valid  : out std_logic;
		key_ready     : in  std_logic;
		ginv_address  : out std_logic_vector(p_num_bits - 1 downto 0);
		ginv_data_out : in  t_shared(1 downto 0);
		f_address     : out std_logic_vector(p_num_bits - 1 downto 0);
		f_data_out    : in  t_shared(1 downto 0);
		c_address     : out std_logic_vector(p_num_bits - 1 downto 0);
		c_data_out    : in  std_logic_vector(q_num_bits - 1 downto 0);
		to_rq_mult    : out rq_mult_msk_in_type;
		from_rq_mult  : in  rq_mult_msk_out_type
		--to_freeze_round   : out mod3_freeze_round_in_type;
		--from_freeze_round : in  mod3_freeze_round_out_type
	);
end entity decryption_msk;

architecture RTL of decryption_msk is

	type state_type is (idle, load_Rq, mult_Rq_start, mult_Rq, mult_freeze, mult_freeze_done, mult_R3, calc_weight, calc_weight_end, output_masked_weight, done_state, done_state2);
	signal state_decrypt : state_type;

	constant mod3_delay : integer := 25 + 5;
	constant mux_delay  : integer := 2;

	signal rq_mult_start            : std_logic;
	signal rq_mult_ready            : std_logic;
	signal rq_mult_output_valid     : std_logic;
	signal rq_mult_output_greater_0 : t_shared(0 downto 0);
	signal rq_mult_output           : t_shared(q_num_bits - 1 downto 0);
	signal rq_mult_done             : std_logic;
	signal rq_mult_load_c           : std_logic;

	signal calc_weight_start             : std_logic;
	signal calc_weight_input_address     : std_logic_vector(p_num_bits - 1 downto 0);
	signal calc_weight_input             : t_shared(1 downto 0);
	signal calc_weight_mask_output       : t_shared(0 downto 0);
	signal calc_weight_mask_output_valid : std_logic;

	signal calc_weight_rand_in : std_logic_vector(level_rand_requirement + and_pini_nrnd * 10 - 1 downto 0);

	signal reg_mask_output : t_shared(0 downto 0);

	signal mod3_input     : t_shared(q_num_bits - 1 downto 0);
	signal mod3_rnd_input : std_logic_vector(and_pini_mul_nrnd * 46 - 1 downto 0);
	signal mod3_output    : t_shared(1 downto 0);

	signal mod3_output_valid_pipe : std_logic_vector(mod3_delay - 1 downto 0);

	signal bram_e_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_e_write_a    : std_logic;
	signal bram_e_data_in_a  : t_shared(1 downto 0);
	signal bram_e_data_out_a : t_shared(1 downto 0);
	signal bram_e_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_e_write_b    : std_logic;
	signal bram_e_data_in_b  : t_shared(1 downto 0);
	signal bram_e_data_out_b : t_shared(1 downto 0);

	signal bram_e_address_a_fsm : std_logic_vector(p_num_bits - 1 downto 0);

	signal counter : integer range 0 to p;

	signal key_ready_pipe : std_logic;

	signal r3_mult_start         : std_logic;
	signal r3_mult_ready         : std_logic;
	signal r3_mult_output_valid  : std_logic;
	signal r3_mult_output        : t_shared(1 downto 0);
	signal r3_mult_done          : std_logic;
	signal r3_mult_input_address : std_logic_vector(p_num_bits - 1 downto 0);
	signal r3_mult_input         : t_shared(1 downto 0);
	signal r3_mult_rnd_input     : std_logic_vector(and_pini_mul_nrnd * 6 - 1 downto 0);
	signal r3_load_array_start   : std_logic;
	signal r3_load_array_address : std_logic_vector(p_num_bits - 1 downto 0);
	signal r3_load_array_input   : t_shared(1 downto 0);

	signal mux_e_input         : std_logic_vector(2 * shares - 1 downto 0);
	signal mux_overwrite_input : std_logic_vector(2 * shares - 1 downto 0);
	signal mux_s_input         : std_logic_vector(shares - 1 downto 0);
	signal mux_rnd             : std_logic_vector(and_pini_nrnd * 2 - 1 downto 0);
	signal mux_out             : std_logic_vector(2 * shares - 1 downto 0);

	signal output_valid_pipe : std_logic_vector(mux_delay - 1 downto 0);

begin

	fsm_process : process(clock, reset) is
	begin
		if reset = '1' then
			state_decrypt        <= idle;
			done                 <= '0';
			calc_weight_start    <= '0';
			r3_mult_start        <= '0';
			--rq_mult3_enable   <= '0';
			rq_mult_start        <= '0';
			rq_mult_load_c       <= '0';
			r3_load_array_start  <= '0';
		elsif rising_edge(clock) then
			case state_decrypt is
				when idle =>
					if start = '1' then
						state_decrypt  <= load_Rq;
						rq_mult_load_c <= '1';
					end if;

					output_valid_pipe(0) <= '0';
					counter <= 0;
					done    <= '0';

				when load_Rq =>
					rq_mult_load_c <= '0';
					counter        <= counter + 1;

					if counter = p then
						state_decrypt <= mult_Rq_start;
						counter       <= p - 1;
					end if;
				when mult_Rq_start =>
					state_decrypt <= mult_Rq;
					rq_mult_start <= '1';
				when mult_Rq =>
					rq_mult_load_c <= '0';
					if rq_mult_output_valid = '1' then
						state_decrypt       <= mult_freeze;
						r3_load_array_start <= '1';
					end if;

					rq_mult_start <= '0';
				when mult_freeze =>
					if mod3_output_valid_pipe(mod3_delay - 1) = '1' then
						counter <= counter - 1;
					end if;
					if rq_mult_done = '1' then
						state_decrypt <= mult_freeze_done;
					end if;

					r3_load_array_start <= '0';
					rq_mult_load_c      <= '0';
				when mult_freeze_done =>
					rq_mult_load_c <= '0';
					if mod3_output_valid_pipe(mod3_delay - 1) = '1' then
						counter <= counter - 1;
					end if;
					if mod3_output_valid_pipe(mod3_delay - 1) = '0' then
						state_decrypt <= mult_R3;
						r3_mult_start <= '1';

						counter <= 0;
					end if;
				when mult_R3 =>
					if r3_mult_done = '1' then
						state_decrypt     <= calc_weight;
						calc_weight_start <= '1';
					end if;

					r3_mult_start <= '0';

					if r3_mult_output_valid = '1' then
						counter <= counter + 1;
					end if;
				when calc_weight =>
					if r3_mult_output_valid = '1' then
						counter <= counter + 1;
					else
						counter <= 0;
					end if;

					if calc_weight_mask_output_valid = '1' then
						state_decrypt <= calc_weight_end;
						counter       <= p - 1;
					end if;

					calc_weight_start <= '0';
				when calc_weight_end =>
					counter       <= counter - 1;
					state_decrypt <= output_masked_weight;
				when output_masked_weight =>
					counter              <= counter - 1;
					output_valid_pipe(0) <= '1';
					if counter = 0 then -- To p so final element is also output
						state_decrypt <= done_state;
					end if;
				when done_state =>
					state_decrypt <= done_state2;
				when done_state2 =>
					done                 <= '1';
					output_valid_pipe(0) <= '0';

					state_decrypt <= idle;
			end case;
		end if;
	end process fsm_process;

	output_valid_pipe(mux_delay - 1 downto 1) <= output_valid_pipe(mux_delay - 2 downto 0) when rising_edge(clock);
	output_valid                              <= output_valid_pipe(mux_delay - 1);

	bram_e_address_a_fsm <= std_logic_vector(to_unsigned(counter, p_num_bits));
	bram_e_write_a       <= mod3_output_valid_pipe(mod3_delay - 1) when state_decrypt /= mult_R3 and state_decrypt /= calc_weight else r3_mult_output_valid;
	bram_e_data_in_a     <= mod3_output when state_decrypt /= mult_R3 and state_decrypt /= calc_weight else r3_mult_output;

	bram_e_address_a <= bram_e_address_a_fsm when state_decrypt = mult_freeze or state_decrypt = mult_freeze_done or --
	                    state_decrypt = output_masked_weight or state_decrypt = calc_weight_end or state_decrypt = mult_R3 else calc_weight_input_address;

	bram_e_address_b <= r3_mult_input_address;

	r3_mult_input    <= bram_e_data_out_b when state_decrypt = mult_R3 or state_decrypt = mult_freeze_done else (others => (others => '0'));
	bram_e_write_b   <= '0';
	bram_e_data_in_b <= (others => (others => '0'));

	ginv_address        <= r3_load_array_address;
	r3_load_array_input <= ginv_data_out;

	calc_weight_input <= bram_e_data_out_a when state_decrypt = calc_weight else (others => (others => '0'));

	mux_e_input                                  <= t_shared_flatten(bram_e_data_out_a, 2) when state_decrypt = output_masked_weight or state_decrypt = done_state else (others => '0');
	mux_overwrite_input(0)                       <= '1' when (state_decrypt = output_masked_weight or state_decrypt = done_state) and counter <= 2 * t else '0';
	mux_overwrite_input(2 * shares - 1 downto 1) <= (others => '0');
	mux_s_input                                  <= t_shared_flatten(reg_mask_output, 1) when state_decrypt = output_masked_weight or state_decrypt = done_state else (others => '0');

	mux_rnd <= rnd_input(and_pini_nrnd * 2 - 1 downto 0);

	output <= t_shared_pack(mux_out, 2) when output_valid_pipe(mux_delay - 1) = '1' else (others => (others => '0'));

	mux2_gadget_inst : entity work.mux2_gadget
		generic map(
			d    => shares,
			word => 2
		)
		port map(
			clk     => clock,
			a_input => mux_overwrite_input,
			b_input => mux_e_input,
			s_input => mux_s_input,
			rnd     => mux_rnd,
			out_mux => mux_out
		);

	rq_mult_ready <= from_rq_mult.ready;
	rq_mult_done  <= from_rq_mult.done;
	c_address     <= from_rq_mult.bram_f_address;
	f_address     <= from_rq_mult.bram_g_address;

	rq_mult_output_valid     <= from_rq_mult.output_valid;
	rq_mult_output_greater_0 <= from_rq_mult.output_greater_0;
	rq_mult_output           <= from_rq_mult.output;

	to_rq_mult.start      <= rq_mult_start;
	to_rq_mult.output_ack <= '1';
	to_rq_mult.load_f     <= rq_mult_load_c;

	to_rq_mult.bram_f_data_out <= c_data_out;
	to_rq_mult.bram_g_data_out <= f_data_out;

	calc_weight_rand_in <= rnd_input(and_pini_nrnd * 2 + level_rand_requirement + and_pini_nrnd * 10 - 1 downto and_pini_nrnd * 2);

	calc_weight_msk_inst : entity work.calc_weight_msk
		port map(
			clock             => clock,
			reset             => reset,
			start             => calc_weight_start,
			input             => calc_weight_input,
			input_address     => calc_weight_input_address,
			rand_in           => calc_weight_rand_in,
			mask_output       => calc_weight_mask_output,
			mask_output_valid => calc_weight_mask_output_valid
		);

	reg_mask_output <= calc_weight_mask_output when rising_edge(clock) and calc_weight_mask_output_valid = '1';

	mod3_input <= rq_mult_output when rq_mult_output_valid = '1' else (others => (others => '0'));

	mod3_rnd_input <= rnd_input(and_pini_nrnd * 2 + level_rand_requirement + and_pini_nrnd * 10 + and_pini_mul_nrnd * 46 - 1 downto and_pini_nrnd * 2 + level_rand_requirement + and_pini_nrnd * 10);

	mod3_output_valid_pipe(0)                       <= rq_mult_output_valid;
	mod3_output_valid_pipe(mod3_delay - 1 downto 1) <= mod3_output_valid_pipe(mod3_delay - 2 downto 0) when rising_edge(clock);

	mod3_msk_inst : entity work.mod3_msk
		port map(
			clock           => clock,
			reset           => reset,
			mod3_input      => mod3_input,
			input_greater_0 => rq_mult_output_greater_0,
			rnd_input       => mod3_rnd_input,
			mod3_output     => mod3_output
		);

	r3_mult_rnd_input <= rnd_input(and_pini_nrnd * 2 + level_rand_requirement + and_pini_nrnd * 10 + and_pini_mul_nrnd * 46 + and_pini_mul_nrnd * 6 - 1 downto and_pini_nrnd * 2 + level_rand_requirement + and_pini_nrnd * 10 + and_pini_mul_nrnd * 46);

	r3_mult_msk_inst : entity work.r3_mult_msk
		port map(
			clock              => clock,
			reset              => reset,
			start_mult         => r3_mult_start,
			mult_input_address => r3_mult_input_address,
			mult_input         => r3_mult_input,
			output             => r3_mult_output,
			output_valid       => r3_mult_output_valid,
			done               => r3_mult_done,
			rnd_input          => r3_mult_rnd_input,
			load_array_start   => r3_load_array_start,
			load_array_address => r3_load_array_address,
			load_array_input   => r3_load_array_input
		);

	ram_msk_e : entity work.ram_msk
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => 2
		)
		port map(
			clock      => clock,
			address_a  => bram_e_address_a,
			write_a    => bram_e_write_a,
			data_in_a  => bram_e_data_in_a,
			data_out_a => bram_e_data_out_a,
			address_b  => bram_e_address_b,
			write_b    => bram_e_write_b,
			data_in_b  => bram_e_data_in_b,
			data_out_b => bram_e_data_out_b
		);

end architecture RTL;
