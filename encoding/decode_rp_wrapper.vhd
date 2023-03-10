library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;

entity decode_rp_wrapper is
	port(
		clock               : in  std_logic;
		reset               : in  std_logic;
		start               : in  std_logic;
		input               : in  std_logic_vector(7 downto 0);
		input_read_address  : out std_logic_vector(Cipher_bytes_bits - 1 downto 0);
		input_write_address : in  std_logic_vector(Cipher_bytes_bits - 1 downto 0);
		input_valid         : in  std_logic;
		input_ack           : out std_logic;
		rounded_decode      : in  std_logic;
		output              : out std_logic_vector(q_num_bits - 1 downto 0);
		output_valid        : out std_logic;
		done                : out std_logic
	);
end entity decode_rp_wrapper;

architecture RTL of decode_rp_wrapper is

	type state_type is (idle, load_bram, start_rp_decode, done_state);
	signal state_decode : state_type;

	signal start_rp : std_logic;
	signal done_rp  : std_logic;

	signal state_l : std_logic_vector(4 downto 0);
	signal state_e : std_logic_vector(4 downto 0);
	signal state_s : std_logic_vector(4 downto 0);

	signal rp_rd_addr : std_logic_vector(10 downto 0);
	signal rp_rd_data : std_logic_vector(8 - 1 downto 0);

	signal cd_wr_addr : std_logic_vector(p_num_bits - 1 downto 0);
	signal cd_wr_data : std_logic_vector(q_num_bits downto 0);

	signal cd_wr_en : std_logic;

	signal state_max       : std_logic_vector(4 downto 0);
	signal param_r_max     : std_logic_vector(p_num_bits - 2 downto 0);
	signal param_ro_max    : std_logic_vector(p_num_bits - 1 downto 0);
	signal param_small_r2  : std_logic;
	signal param_state_ct  : std_logic_vector(10 downto 0);
	signal param_ri_offset : std_logic_vector(p_num_bits - 2 downto 0);
	signal param_ri_len    : std_logic_vector(p_num_bits - 2 downto 0);
	signal param_ro_offset : std_logic_vector(p_num_bits - 2 downto 0);
	signal param_m0        : std_logic_vector(q_num_bits downto 0);
	signal param_m0inv     : std_logic_vector(q_num_bits * 2 downto 0);

	signal param_outs1       : std_logic_vector(1 downto 0);
	signal param_outsl       : std_logic_vector(1 downto 0);
	signal param_outsl_first : std_logic_vector(1 downto 0);
	signal param_r_s1        : std_logic_vector(1 downto 0);
	signal param_r_sl        : std_logic_vector(1 downto 0);
	signal param_outoffset   : std_logic_vector(p_num_bits downto 0);

	signal publickey_state_max       : std_logic_vector(4 downto 0);
	signal publickey_param_r_max     : std_logic_vector(p_num_bits - 2 downto 0);
	signal publickey_param_ro_max    : std_logic_vector(p_num_bits - 1 downto 0);
	signal publickey_param_small_r2  : std_logic;
	signal publickey_param_state_ct  : std_logic_vector(10 downto 0);
	signal publickey_param_ri_offset : std_logic_vector(p_num_bits - 2 downto 0);
	signal publickey_param_ri_len    : std_logic_vector(p_num_bits - 2 downto 0);
	signal publickey_param_ro_offset : std_logic_vector(p_num_bits - 2 downto 0);
	signal publickey_param_m0        : std_logic_vector(q_num_bits downto 0);
	signal publickey_param_m0inv     : std_logic_vector(q_num_bits * 2 downto 0);

	signal publickey_param_outs1       : std_logic_vector(1 downto 0);
	signal publickey_param_outsl       : std_logic_vector(1 downto 0);
	signal publickey_param_outsl_first : std_logic_vector(1 downto 0);
	signal publickey_param_r_s1        : std_logic_vector(1 downto 0);
	signal publickey_param_r_sl        : std_logic_vector(1 downto 0);
	signal publickey_param_outoffset   : std_logic_vector(p_num_bits downto 0);

	signal ciphertext_state_max       : std_logic_vector(4 downto 0);
	signal ciphertext_param_r_max     : std_logic_vector(p_num_bits - 2 downto 0);
	signal ciphertext_param_ro_max    : std_logic_vector(p_num_bits - 1 downto 0);
	signal ciphertext_param_small_r2  : std_logic;
	signal ciphertext_param_state_ct  : std_logic_vector(10 downto 0);
	signal ciphertext_param_ri_offset : std_logic_vector(p_num_bits - 2 downto 0);
	signal ciphertext_param_ri_len    : std_logic_vector(p_num_bits - 2 downto 0);
	signal ciphertext_param_ro_offset : std_logic_vector(p_num_bits - 2 downto 0);
	signal ciphertext_param_m0        : std_logic_vector(q_num_bits downto 0);
	signal ciphertext_param_m0inv     : std_logic_vector(q_num_bits * 2 downto 0);

	signal ciphertext_param_outs1       : std_logic_vector(1 downto 0);
	signal ciphertext_param_outsl       : std_logic_vector(1 downto 0);
	signal ciphertext_param_outsl_first : std_logic_vector(1 downto 0);
	signal ciphertext_param_r_s1        : std_logic_vector(1 downto 0);
	signal ciphertext_param_r_sl        : std_logic_vector(1 downto 0);
	signal ciphertext_param_outoffset   : std_logic_vector(p_num_bits downto 0);

	signal bram_read_address  : std_logic_vector(Cipher_bytes_bits - 1 downto 0);
	signal bram_read_data_out : std_logic_vector(8 - 1 downto 0);

	signal bram_write_address : std_logic_vector(Cipher_bytes_bits - 1 downto 0);
	signal bram_write_data_in : std_logic_vector(7 downto 0);

	signal bram_write_enable : std_logic;

	signal counter : integer range 0 to PublicKeys_bytes;

	signal rounded_decode_pipe : std_logic;
	signal rounded_decode_pipe2 : std_logic;

	signal input_slow_internal : std_logic;

	signal input_slow: std_logic;
begin

	decode_wrapper_process : process(clock, reset) is
	begin
		if reset = '1' then
			state_decode <= idle;
			start_rp     <= '0';
			done         <= '0';
		elsif rising_edge(clock) then
			case state_decode is
				when idle =>
					if start = '1' then
						state_decode <= load_bram;
						start_rp     <= '1';
					end if;

					counter             <= 0;
					done                <= '0';
					input_slow_internal <= input_slow;
				when load_bram =>
					if input_valid = '1' then
						counter <= counter + 1;
					end if;

					if rounded_decode_pipe2 = '1' and seperate_cipher_decode = false and done_rp = '0' then
						state_decode <= start_rp_decode;
					end if;

					if (counter = PublicKeys_bytes / 2 and input_slow_internal = '0') or (counter = PublicKeys_bytes + 1 and input_slow_internal = '1') then
						state_decode <= start_rp_decode;
						counter      <= 0;
					end if;

					if (counter = 7 and input_slow_internal = '0') or counter = 10 then
						start_rp <= '0';
					end if;
				when start_rp_decode =>
					start_rp <= '0';
					if done_rp = '1' then
						state_decode <= done_state;
					end if;

					null;
				when done_state =>
					if done_rp = '1' and cd_wr_en = '0' then
						state_decode <= idle;
						done         <= '1';
					end if;
			end case;
		end if;
	end process decode_wrapper_process;

	input_ack <= '1' when (state_decode = load_bram) and input_valid = '1' else '0';

	rounded_decode_pipe <= rounded_decode when rising_edge(clock);
	rounded_decode_pipe2 <= rounded_decode_pipe when rising_edge(clock);

	state_max    <= ciphertext_state_max when rounded_decode_pipe = '1' and seperate_cipher_decode = false else publickey_state_max;
	param_r_max  <= ciphertext_param_r_max when rounded_decode_pipe = '1' and seperate_cipher_decode = false else publickey_param_r_max;
	param_ro_max <= ciphertext_param_ro_max when rounded_decode_pipe = '1' and seperate_cipher_decode = false else publickey_param_ro_max;

	param_small_r2  <= ciphertext_param_small_r2 when rounded_decode_pipe = '1' and seperate_cipher_decode = false else publickey_param_small_r2;
	param_state_ct  <= ciphertext_param_state_ct when rounded_decode_pipe = '1' and seperate_cipher_decode = false else publickey_param_state_ct;
	param_ri_offset <= ciphertext_param_ri_offset when rounded_decode_pipe = '1' and seperate_cipher_decode = false else publickey_param_ri_offset;
	param_ri_len    <= ciphertext_param_ri_len when rounded_decode_pipe = '1' and seperate_cipher_decode = false else publickey_param_ri_len;

	param_ro_offset <= ciphertext_param_ro_offset when rounded_decode_pipe = '1' and seperate_cipher_decode = false else publickey_param_ro_offset;

	param_m0    <= ciphertext_param_m0 when rounded_decode_pipe = '1' and seperate_cipher_decode = false else publickey_param_m0;
	param_m0inv <= ciphertext_param_m0inv when rounded_decode_pipe = '1' and seperate_cipher_decode = false else publickey_param_m0inv;

	param_outs1       <= ciphertext_param_outs1 when rounded_decode_pipe = '1' and seperate_cipher_decode = false else publickey_param_outs1;
	param_outsl       <= ciphertext_param_outsl when rounded_decode_pipe = '1' and seperate_cipher_decode = false else publickey_param_outsl;
	param_outsl_first <= ciphertext_param_outsl_first when rounded_decode_pipe = '1' and seperate_cipher_decode = false else publickey_param_outsl_first;
	param_r_s1        <= ciphertext_param_r_s1 when rounded_decode_pipe = '1' and seperate_cipher_decode = false else publickey_param_r_s1;
	param_r_sl        <= ciphertext_param_r_sl when rounded_decode_pipe = '1' and seperate_cipher_decode = false else publickey_param_r_sl;
	param_outoffset   <= ciphertext_param_outoffset when rounded_decode_pipe = '1' and seperate_cipher_decode = false else publickey_param_outoffset;

	bram_write_enable  <= input_valid when state_decode = load_bram else '0';
	bram_write_address <= input_write_address; -- TODO this might set 1 bit too few for sntrip1277
	bram_write_data_in <= input;

	bram_read_address <= rp_rd_addr(Cipher_bytes_bits - 1 downto 0);
	rp_rd_data        <= bram_read_data_out when rounded_decode_pipe = '0' or seperate_cipher_decode = true else input(7 downto 0);

	input_read_address <= rp_rd_addr(Cipher_bytes_bits - 1 downto 0);

	output_valid <= cd_wr_en when state_decode = start_rp_decode or state_decode = load_bram else '0';
	output       <= cd_wr_data(q_num_bits - 1 downto 0);

	input_slow <= '1';
	
	decode_rp_inst : entity work.decode_rp
		port map(
			clk             => clock,
			start           => start_rp,
			done            => done_rp,
			rp_rd_addr      => rp_rd_addr,
			rp_rd_data      => rp_rd_data,
			cd_wr_addr      => cd_wr_addr,
			cd_wr_data      => cd_wr_data,
			cd_wr_en        => cd_wr_en,
			state_l         => state_l,
			state_e         => state_e,
			state_s         => state_s,
			state_max       => state_max,
			param_r_max     => param_r_max,
			param_ro_max    => param_ro_max,
			param_small_r2  => param_small_r2,
			param_state_ct  => param_state_ct,
			param_ri_offset => param_ri_offset,
			param_ri_len    => param_ri_len,
			param_outoffset => param_outoffset,
			param_outs1     => param_outs1,
			param_outsl     => param_outsl,
			param_m0        => param_m0,
			param_m0inv     => param_m0inv,
			param_ro_offset => param_ro_offset
		);

	param_sntrup761 : if use_parameter_set = sntrup761 generate
		rp761q4591decode_param_inst : entity work.rp761q4591decode_param
			port map(
				state_l         => state_l,
				state_e         => state_e,
				state_s         => state_s,
				state_max       => publickey_state_max,
				param_r_max     => publickey_param_r_max,
				param_ro_max    => publickey_param_ro_max,
				param_small_r2  => publickey_param_small_r2,
				param_state_ct  => publickey_param_state_ct,
				param_ri_offset => publickey_param_ri_offset,
				param_ri_len    => publickey_param_ri_len,
				param_outoffset => publickey_param_outoffset,
				param_outs1     => publickey_param_outs1,
				param_outsl     => publickey_param_outsl,
				param_m0        => publickey_param_m0,
				param_m0inv     => publickey_param_m0inv,
				param_ro_offset => publickey_param_ro_offset
			);

		gen_cipher_decode_param : if seperate_cipher_decode = false generate
			rp761q1531decode_param_inst : entity work.rp761q1531decode_param
				port map(
					state_l         => state_l,
					state_e         => state_e,
					state_s         => state_s,
					state_max       => ciphertext_state_max,
					param_r_max     => ciphertext_param_r_max,
					param_ro_max    => ciphertext_param_ro_max,
					param_small_r2  => ciphertext_param_small_r2,
					param_state_ct  => ciphertext_param_state_ct,
					param_ri_offset => ciphertext_param_ri_offset,
					param_ri_len    => ciphertext_param_ri_len,
					param_outoffset => ciphertext_param_outoffset,
					param_outs1     => ciphertext_param_outs1,
					param_outsl     => ciphertext_param_outsl,
					param_m0        => ciphertext_param_m0,
					param_m0inv     => ciphertext_param_m0inv,
					param_ro_offset => ciphertext_param_ro_offset
				);
		end generate gen_cipher_decode_param;
	end generate param_sntrup761;

	bram_p_inst : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => Cipher_bytes_bits,
			DATA_WIDTH    => 8
		)
		port map(
			clock      => clock,
			address_a  => bram_read_address,
			write_a    => '0',
			data_in_a  => (others => '0'),
			data_out_a => bram_read_data_out,
			address_b  => bram_write_address(Cipher_bytes_bits - 1 downto 0),
			write_b    => bram_write_enable,
			data_in_b  => bram_write_data_in,
			data_out_b => open
		);

end architecture RTL;
