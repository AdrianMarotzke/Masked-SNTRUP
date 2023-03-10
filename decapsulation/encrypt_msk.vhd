library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;
use work.interfaces_32_ska.all;

-- Core masked encryption of NTRU prime, without any de or encoding
-- Public key is input with highest degree first.
-- c is output with highest degree first
entity encrypt_msk is
	port(
		clock                       : in  std_logic;
		reset                       : in  std_logic;
		ready                       : out std_logic;
		done                        : out std_logic;
		rand_input                  : in  std_logic_vector(and_pini_nrnd * q_num_bits + level_rand_requirement * 2 + and_pini_mul_nrnd * 46 - 1 downto 0);
		start_encap                 : in  std_logic;
		new_public_key              : in  std_logic;
		public_key_in               : in  std_logic_vector(q_num_bits - 1 downto 0);
		public_key_valid            : in  std_logic;
		public_key_ready            : out std_logic;
		c_encrypt                   : out t_shared(q_num_bits - 1 downto 0);
		c_encrypt_valid             : out std_logic;
		r_secret                    : out t_shared(1 downto 0);
		r_secret_valid              : out std_logic;
		short_weights_start         : out std_logic;
		short_weights_output_enable : out std_logic;
		short_weights_in            : in  t_shared(1 downto 0);
		short_weights_valid         : in  std_logic;
		to_rq_mult                  : out rq_mult_msk_in_type;
		from_rq_mult                : in  rq_mult_msk_out_type;
		to_freeze_round             : out mod3_freeze_round_in_type;
		from_freeze_round           : in  mod3_freeze_round_out_type
	);
end entity encrypt_msk;

architecture RTL of encrypt_msk is

	type state_type is (init_state, write_public_key, write_key_and_get_weight, ready_state, get_small_state, wait_state1, wait_state2, multiply_state, done_state);
	signal state_encap : state_type := init_state;

	signal p_counter : integer range 0 to p;
	signal s_counter : integer range 0 to p;

	signal rq_mult_start              : std_logic;
	signal rq_mult_ready              : std_logic;
	signal rq_mult_output_valid       : std_logic;
	signal rq_mult_output             : t_shared(q_num_bits - 1 downto 0);
	signal rq_mult_output_ack         : std_logic;
	signal rq_mult_done               : std_logic;
	signal rq_mult_load_rq            : std_logic;
	signal rq_mult_bram_pk_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal rq_mult_bram_pk_data_out_a : std_logic_vector(q_num_bits - 1 downto 0);
	--signal rq_mult_bram_pk_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	--signal rq_mult_bram_pk_data_out_b : std_logic_vector(q_num_bits - 1 downto 0);
	signal rq_mult_bram_r_address_a   : std_logic_vector(p_num_bits - 1 downto 0);
	signal rq_mult_bram_r_data_out_a  : t_shared(2 - 1 downto 0);
	--signal rq_mult_bram_r_address_b   : std_logic_vector(p_num_bits - 1 downto 0);
	--signal rq_mult_bram_r_data_out_b  : t_shared(2 - 1 downto 0);

	signal bram_pk_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_pk_write_a    : std_logic;
	signal bram_pk_data_in_a  : std_logic_vector(q_num_bits - 1 downto 0);
	signal bram_pk_data_out_a : std_logic_vector(q_num_bits - 1 downto 0);
	signal bram_pk_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_pk_write_b    : STD_LOGIC;
	signal bram_pk_data_in_b  : std_logic_vector(q_num_bits - 1 downto 0);
	signal bram_pk_data_out_b : std_logic_vector(q_num_bits - 1 downto 0);

	signal bram_r_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_r_write_a    : std_logic;
	signal bram_r_data_in_a  : t_shared(1 downto 0);
	signal bram_r_data_out_a : t_shared(1 downto 0);
	signal bram_r_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_r_write_b    : std_logic;
	signal bram_r_data_in_b  : t_shared(1 downto 0);
	signal bram_r_data_out_b : t_shared(1 downto 0);

	signal rq_round_input        : t_shared(q_num_bits - 1 downto 0);
	signal rq_round_output       : t_shared(q_num_bits - 1 downto 0);
	signal rq_round_input_valid  : std_logic;
	signal rq_round_output_valid : std_logic;

begin

	fsm_process : process(clock, reset) is
	begin
		if reset = '1' then
			state_encap <= init_state;

			ready                       <= '0';
			done                        <= '0';
			public_key_ready            <= '0';
			short_weights_start         <= '0';
			short_weights_output_enable <= '0';
			rq_mult_start               <= '0';
			rq_mult_load_rq             <= '0';
		elsif rising_edge(clock) then
			case state_encap is
				when init_state =>
					if new_public_key = '1' and start_encap = '0' then
						state_encap <= write_public_key;
					end if;
					if new_public_key = '1' and start_encap = '1' then
						state_encap         <= write_key_and_get_weight;
						short_weights_start <= '1';
					end if;
					p_counter        <= 0;
					s_counter        <= 0;
					ready            <= '1';
					public_key_ready <= '0';

					short_weights_output_enable <= '0';
					rq_mult_load_rq             <= '0';
				when write_key_and_get_weight =>
					if public_key_valid = '1' and p_counter /= p - 1 then
						p_counter <= p_counter + 1;
					end if;
					if p_counter = p - 1 and public_key_valid = '1' then
						state_encap                 <= get_small_state;
						public_key_ready            <= '1';
						p_counter                   <= 0;
						short_weights_output_enable <= '1';
					end if;
					ready               <= '0';
					short_weights_start <= '0';
					rq_mult_load_rq     <= '0';

					if public_key_valid = '1' then
						short_weights_output_enable <= '1';
					end if;
					if short_weights_valid = '1' then
						s_counter       <= s_counter + 1;
						rq_mult_load_rq <= '1';
					end if;
					if s_counter = p then
						short_weights_output_enable <= '0';
					end if;
				when write_public_key =>
					if public_key_valid = '1' and p_counter /= p - 1 then
						p_counter <= p_counter + 1;
					end if;
					if p_counter = p - 1 and public_key_valid = '1' then
						state_encap      <= ready_state;
						public_key_ready <= '1';
					end if;
					ready <= '0';
				when ready_state =>
					short_weights_output_enable <= '0';
					s_counter                   <= 0;

					if start_encap = '1' AND new_public_key = '0' then
						state_encap                 <= get_small_state;
						short_weights_start         <= '1';
						short_weights_output_enable <= '1';
					end if;
					if new_public_key = '1' and start_encap = '0' then
						state_encap      <= write_public_key;
						p_counter        <= 0;
						public_key_ready <= '0';
					end if;
					if new_public_key = '1' and start_encap = '1' then
						state_encap         <= write_key_and_get_weight;
						short_weights_start <= '1';
						p_counter           <= 0;
						public_key_ready    <= '0';
					end if;
					ready <= '1';
					done  <= '0';
				when get_small_state =>
					rq_mult_load_rq     <= '0';
					if short_weights_valid = '1' then
						s_counter       <= s_counter + 1;
						rq_mult_load_rq <= '1';
					end if;
					if s_counter = p then
						state_encap                 <= wait_state1;
						short_weights_output_enable <= '0';
						rq_mult_start               <= '1';
					end if;
					short_weights_start <= '0';
					ready               <= '0';
				when wait_state1 =>
					state_encap <= wait_state2;
				when wait_state2 =>
					state_encap   <= multiply_state;
					rq_mult_start <= '1';
				when multiply_state =>
					rq_mult_load_rq <= '0';
					if rq_mult_done = '1' then
						state_encap <= done_state;
					end if;
					rq_mult_start   <= '0';
				when done_state =>
					if rq_round_output_valid = '0' then
						state_encap <= ready_state;
						done        <= '1';
					end if;
			end case;
		end if;
	end process fsm_process;

	bram_pk_data_in_a <= public_key_in;
	bram_pk_write_a   <= public_key_valid when state_encap = write_public_key or state_encap = write_key_and_get_weight else '0';
	bram_pk_address_a <= std_logic_vector(to_unsigned(p_counter, p_num_bits)) when state_encap = write_public_key or state_encap = write_key_and_get_weight else rq_mult_bram_pk_address_a;

	bram_r_data_in_a <= short_weights_in;

	bram_r_write_a   <= short_weights_valid when state_encap = get_small_state or state_encap = write_key_and_get_weight else '0';
	bram_r_address_a <= std_logic_vector(to_unsigned(s_counter, p_num_bits)) when state_encap = get_small_state or state_encap = write_key_and_get_weight else rq_mult_bram_r_address_a;

	--bram_pk_address_b <= rq_mult_bram_pk_address_b;
	--bram_r_address_b  <= rq_mult_bram_r_address_a;

	rq_mult_bram_pk_data_out_a <= bram_pk_data_out_a;
	--rq_mult_bram_pk_data_out_b <= bram_pk_data_out_b;
	rq_mult_bram_r_data_out_a  <= bram_r_data_out_a when state_encap = multiply_state else (others => (others => '0'));
	--rq_mult_bram_r_data_out_b  <= bram_r_data_out_a;

	rq_round_input       <= rq_mult_output;
	rq_round_input_valid <= rq_mult_output_valid;

	--c_encrypt       <= std_logic_vector(shift_right((resize(signed(rq_round_output), q_num_bits + 2) + q12) * 10923, 15)(q_num_bits - 1 downto 0)) when rising_edge(clock);
	c_encrypt       <= rq_round_output when rising_edge(clock);
	c_encrypt_valid <= rq_round_output_valid when rising_edge(clock);

	r_secret       <= short_weights_in;
	r_secret_valid <= short_weights_valid;

	rq_mult_output_ack <= '1';

	to_rq_mult.start           <= rq_mult_start;
	to_rq_mult.output_ack      <= rq_mult_output_ack;
	to_rq_mult.load_f          <= rq_mult_load_rq;
	to_rq_mult.bram_f_data_out <= rq_mult_bram_pk_data_out_a;
	to_rq_mult.bram_g_data_out <= rq_mult_bram_r_data_out_a;
	rq_mult_ready              <= from_rq_mult.ready;
	rq_mult_output_valid       <= from_rq_mult.output_valid;
	rq_mult_output             <= from_rq_mult.output;
	rq_mult_done               <= from_rq_mult.done;

	rq_mult_bram_pk_address_a <= from_rq_mult.bram_f_address;
	rq_mult_bram_r_address_a  <= from_rq_mult.bram_g_address;

	round_msk_inst : entity work.round_msk
		port map(
			clock           => clock,
			reset           => reset,
			rand_input      => rand_input,
			input           => rq_round_input,
			input_greater_0 => from_rq_mult.output_greater_0,
			enable          => rq_round_input_valid,
			output          => open,
			output_rounded  => rq_round_output,
			output_valid    => rq_round_output_valid
		);

	block_ram_pk : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => q_num_bits
		)
		port map(
			clock      => clock,
			address_a  => bram_pk_address_a,
			write_a    => bram_pk_write_a,
			data_in_a  => bram_pk_data_in_a,
			data_out_a => bram_pk_data_out_a,
			address_b  => bram_pk_address_b,
			write_b    => bram_pk_write_b,
			data_in_b  => bram_pk_data_in_b,
			data_out_b => bram_pk_data_out_b
		);

	block_ram_r : entity work.ram_msk
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => 2
		)
		port map(
			clock      => clock,
			address_a  => bram_r_address_a,
			write_a    => bram_r_write_a,
			data_in_a  => bram_r_data_in_a,
			data_out_a => bram_r_data_out_a,
			address_b  => bram_r_address_b,
			write_b    => bram_r_write_b,
			data_in_b  => bram_r_data_in_b,
			data_out_b => bram_r_data_out_b
		);

	-- Unused, tied to zero
	bram_r_write_b  <= '0';
	bram_pk_write_b <= '0';
end architecture RTL;
