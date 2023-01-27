library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;
use work.interfaces_64_ska.all;

entity sha_512_wrapper_msk is
	port(
		clock                 : in  std_logic;
		reset                 : in  std_logic;
		rand_in               : in  std_logic_vector(level_rand_requirement - 1 downto 0);
		new_public_key        : in  std_logic;
		public_key_in         : in  t_shared(7 downto 0);
		new_pk_cache          : in  std_logic;
		pk_cache_in           : in  std_logic_vector(7 downto 0);
		pk_cache_valid        : in  std_logic;
		start_confirm         : in  std_logic;
		confirm_r_hash_only   : in  std_logic;
		r_encoded_in          : in  t_shared(7 downto 0);
		r_encoded_in_valid    : in  std_logic;
		start_session         : in  std_logic;
		re_encap_session      : in  std_logic;
		diff_mask             : in  t_shared(7 downto 0);
		c_encoded_in          : in  std_logic_vector(7 downto 0);
		c_encoded_in_valid    : in  std_logic;
		decode_Rq_input_ack   : in  std_logic;
		decode_Rq_input_valid : in  std_logic;
		sha_512_finished      : out std_logic;
		ack_new_input         : out std_logic;
		sha_512_hash_out      : out t_shared(63 downto 0);
		--hash_confirm_out_valid : out std_logic;
		--hash_confirm_out       : out std_logic_vector(255 downto 0)
		hash_out_address      : in  std_logic_vector(1 downto 0); -- TODO implement
		hash_out_read_pub_key : in  std_logic;
		hash_out_read_confirm : in  std_logic;
		hash_out_read_enable  : in  std_logic
	);
end entity sha_512_wrapper_msk;

architecture RTL of sha_512_wrapper_msk is

	type state_type is (idle, hash_new_pk_start, hash_new_pk, hash_new_pk_final, hash_new_pk_store, load_new_pk_cache, --
	                    hash_confirm_start, hash_confirm, hash_confirm_final, hash_confirm_2, hash_confirm_2_input, hash_confirm_2_wait,
	                    hash_session_start, hash_session_r_enc, hash_session_c, hash_session_c_final, hash_session_c_wait);
	signal state_sha_wrap : state_type;

	--signal decode_Rq_input_valid_pipe : std_logic;
	--signal decode_Rq_input_ack_pipe   : std_logic;
	--signal public_key_in_pipe         : std_logic_vector(7 downto 0);
	signal public_key_in_valid : std_logic;

	signal message_byte       : t_shared(7 downto 0);
	signal message_byte_valid : std_logic;

	signal message_byte_pipe       : t_shared(7 downto 0);
	signal message_byte_valid_pipe : std_logic;

	signal sha_512_data_valid : std_logic;
	signal sha_512_n_blocks   : natural;
	--signal sha_512_msg_block_in : std_logic_vector(0 to 1023);
	signal sha_512_ready      : std_logic;
	signal sha_512_data_out   : t_shared(63 downto 0);

	signal byte_counter  : integer range 0 to 1023;
	signal round_counter : integer range 0 to 10;

	signal sha_512_finished_wrap : std_logic;

	constant number_of_rounds_public_key : integer := PublicKeys_bytes / 128 + 1;

	constant number_of_rounds_r_enc : integer := Small_bytes / 128 + 1;

	constant number_of_rounds_c : integer := (Ciphertexts_bytes + 32 * 2) / 128 + 1;

	constant unpadded_bytes_pub_key : integer := PublicKeys_bytes - 128 * (number_of_rounds_public_key - 1) + 1;

	constant unpadded_bytes_r_enc : integer := Small_bytes - 128 * (number_of_rounds_r_enc - 1) + 1;

	constant unpadded_bytes_c : integer := Ciphertexts_bytes + 32 * 2 - 128 * (number_of_rounds_c - 1) + 1;

	signal fifo_wr_en      : std_logic;
	signal fifo_wr_data    : t_shared(0 to 64 - 1);
	signal fifo_rd_en      : std_logic;
	signal fifo_rd_valid   : std_logic;
	signal fifo_rd_data    : t_shared(64 - 1 downto 0);
	signal fifo_empty      : std_logic;
	signal fifo_empty_next : std_logic;
	signal fifo_full       : std_logic;
	signal fifo_full_next  : std_logic;

	signal fifo_wr_data_counter : integer range 0 to 7;

	procedure incr_fifo(signal fifo_wr_data_counter : inout integer; signal fifo_wr_en : out std_logic) is
	begin
		if fifo_wr_data_counter = 7 then
			fifo_wr_data_counter <= 0;
		else
			fifo_wr_data_counter <= fifo_wr_data_counter + 1;
		end if;
		if fifo_wr_data_counter = 7 - 1 then
			fifo_wr_en <= '1';
		end if;
	end procedure;

	signal cache_address_a_fsm : std_logic_vector(4 - 1 downto 0);
	signal cache_address_a     : std_logic_vector(4 - 1 downto 0);
	signal cache_data_out_a    : t_shared(64 - 1 downto 0);
	signal cache_address_b     : std_logic_vector(4 - 1 downto 0);
	signal cache_write_b       : std_logic;
	signal cache_data_in_b     : t_shared(64 - 1 downto 0);

	signal cache_data_out_a_last_byte : t_shared(8 - 1 downto 0);

	signal cache_address_counter : integer range 0 to 8;
	signal cache_shift_couter    : integer range 0 to 8;

	constant r_enc_cache_offset         : integer := 0;
	constant public_key_cache_offset    : integer := 4;
	constant sha_out_cache_offset       : integer := 8;
	constant confirm_bytes_cache_offset : integer := 12;

	signal c_fifo_rd_en       : std_logic;
	signal c_fifo_rd_valid    : std_logic;
	signal c_fifo_rd_data     : std_logic_vector(8 - 1 downto 0);
	signal c_fifo_rd_data_msk : t_shared(8 - 1 downto 0);
	signal c_fifo_empty       : std_logic;
	signal c_fifo_empty_next  : std_logic;
	signal c_fifo_full        : std_logic;
	signal c_fifo_full_next   : std_logic;

	signal confirm_r_hash_only_pipe : std_logic;
	signal sha_512_rand_in          : std_logic_vector(level_rand_requirement - 1 downto 0);

	function set_length_constant(input : unsigned)
	return t_shared is
		variable temp : t_shared(127 downto 0);
	begin
		temp := (others => (others => '0'));

		for i in 0 to 127 loop
			temp(i)(0) := input(i);
		end loop;
		return temp;
	end function set_length_constant;

	constant small_hash_length : unsigned(127 downto 0) := to_unsigned(8 * (Small_bytes + 1), 128);

	constant small_hash_length_msk : t_shared(127 downto 0) := set_length_constant(small_hash_length);

	constant cipher_hash_length     : unsigned(127 downto 0) := to_unsigned(8 * (Ciphertexts_bytes + 32 * 2 + 1), 128);
	constant cipher_hash_length_msk : t_shared(127 downto 0) := set_length_constant(cipher_hash_length);

	signal pk_cache_in_msk : t_shared(7 downto 0);
begin
	hash_process : process(clock, reset) is
		variable temp_trans      : t_shared_trans;
		variable temp            : t_shared(0 to 7);
		variable temp_vector_128 : std_logic_vector(128 * shares - 1 downto 0);
		variable temp_vector_64  : std_logic_vector(64 * shares - 1 downto 0);
		variable temp_vector_8   : std_logic_vector(8 * shares - 1 downto 0);

	begin
		if reset = '1' then
			state_sha_wrap        <= idle;
			byte_counter          <= 0;
			round_counter         <= 0;
			cache_address_counter <= 0;
			sha_512_data_valid    <= '0';
			--hash_confirm_out_valid <= '0';

			fifo_wr_data_counter <= 0;
			fifo_wr_en           <= '0';
			sha_512_finished     <= '0';
		elsif rising_edge(clock) then
			case state_sha_wrap is
				when idle =>

					if new_pk_cache = '1' then
						state_sha_wrap <= load_new_pk_cache;
					end if;
					if new_public_key = '1' then
						state_sha_wrap <= hash_new_pk_start;
						--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & "00000100";

						temp                 := (others => (others => '0'));
						temp(5)(0)           := '1';
						fifo_wr_data         <= fifo_wr_data(8 to 63) & temp;
						fifo_wr_data_counter <= fifo_wr_data_counter + 1;
						temp                 := (others => (others => '0'));
					end if;
					if start_confirm = '1' then
						state_sha_wrap       <= hash_confirm_start;
						--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & "00000011";
						temp                 := (others => (others => '0'));
						temp(6)(0)           := '1';
						temp(7)(0)           := '1';
						fifo_wr_data         <= fifo_wr_data(8 to 63) & temp;
						fifo_wr_data_counter <= fifo_wr_data_counter + 1;
						temp                 := (others => (others => '0'));
					end if;
					if start_session = '1' then
						state_sha_wrap      <= hash_session_start;
						cache_address_a_fsm <= std_logic_vector(to_unsigned(r_enc_cache_offset, 4)); -- Already set address so memory read is done when needed
					end if;

					fifo_wr_data_counter  <= 0;
					byte_counter          <= 0;
					round_counter         <= 0;
					cache_address_counter <= 0;
					--hash_confirm_out_valid <= '0';
					cache_write_b         <= '0';
					sha_512_finished      <= '0';
					c_fifo_rd_en          <= '0';
				when load_new_pk_cache =>
					cache_write_b <= '0';

					if pk_cache_valid = '1' then
						--public_key_cache <= public_key_cache(255 - 8 downto 0) & pk_cache_in;
						byte_counter    <= byte_counter + 1;
						cache_address_b <= std_logic_vector(to_unsigned(public_key_cache_offset + cache_address_counter, 4));
						cache_data_in_b <= cache_data_in_b(63 - 8 downto 0) & pk_cache_in_msk;
						if byte_counter = 7 then
							cache_write_b         <= '1';
							byte_counter          <= 0;
							cache_address_counter <= cache_address_counter + 1;

							if cache_address_counter = 3 then
								state_sha_wrap <= idle;
							end if;
						end if;
					end if;

					if byte_counter = 31 then
						state_sha_wrap <= idle;
					end if;

				when hash_new_pk_start =>
					fifo_wr_en <= '0';
					if message_byte_valid_pipe = '1' then
						state_sha_wrap <= hash_new_pk;
						--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & message_byte_pipe;
						byte_counter   <= byte_counter + 2;

						fifo_wr_data <= fifo_wr_data(8 to 63) & message_byte_pipe;
						incr_fifo(fifo_wr_data_counter, fifo_wr_en);
					end if;
				when hash_new_pk =>
					sha_512_data_valid <= '0';
					fifo_wr_en         <= '0';
					if message_byte_valid_pipe = '1' then
						--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & message_byte_pipe;
						byte_counter <= byte_counter + 1;

						fifo_wr_data <= fifo_wr_data(8 to 63) & message_byte_pipe;
						incr_fifo(fifo_wr_data_counter, fifo_wr_en);

						if byte_counter >= 127 and sha_512_ready = '1' then
							sha_512_n_blocks   <= number_of_rounds_public_key;
							sha_512_data_valid <= '1';
							byte_counter       <= byte_counter - 127;
							round_counter      <= round_counter + 1;

							if round_counter = number_of_rounds_public_key - 2 then
								state_sha_wrap <= hash_new_pk_final;
							else
								state_sha_wrap <= hash_new_pk;
							end if;
						end if;
					end if;
				when hash_new_pk_final =>
					sha_512_data_valid <= '0';
					fifo_wr_en         <= '0';
					if message_byte_valid_pipe = '1' and byte_counter /= unpadded_bytes_pub_key then
						--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & message_byte_pipe;
						byte_counter <= byte_counter + 1;

						fifo_wr_data <= fifo_wr_data(8 to 63) & message_byte_pipe;
						incr_fifo(fifo_wr_data_counter, fifo_wr_en);
					end if;

					if byte_counter = unpadded_bytes_pub_key then
						--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & "10000000";
						byte_counter <= byte_counter + 1;

						temp(0)(0)   := '1';
						fifo_wr_data <= fifo_wr_data(8 to 63) & temp;
						incr_fifo(fifo_wr_data_counter, fifo_wr_en);
					end if;

					if byte_counter > unpadded_bytes_pub_key and ((byte_counter - unpadded_bytes_pub_key) <= 8) then
						--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & "00000000";
						byte_counter <= byte_counter + 1;

						temp         := (others => (others => '0'));
						fifo_wr_data <= fifo_wr_data(8 to 63) & temp;
						incr_fifo(fifo_wr_data_counter, fifo_wr_en);
					end if;

					if (byte_counter - unpadded_bytes_pub_key) > 8 and byte_counter < 112 then
						--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & "00000000";
						byte_counter <= byte_counter + 8;

						fifo_wr_data         <= (others => (others => '0'));
						fifo_wr_en           <= '1';
						fifo_wr_data_counter <= 7;
					end if;

					if byte_counter >= 112 and byte_counter < 128 then
						--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & std_logic_vector(to_unsigned(8 * (PublicKeys_bytes + 1), 128)((128 - byte_counter) * 8 - 1 downto (127 - byte_counter) * 8));
						byte_counter <= byte_counter + 1;

						-- TODO FIX -- This is only needed for encap
						--fifo_wr_data <= fifo_wr_data(8 to 63) & std_logic_vector(to_unsigned(8 * (PublicKeys_bytes + 1), 128)((128 - byte_counter) * 8 - 1 downto (127 - byte_counter) * 8));
						-- END FIX

						incr_fifo(fifo_wr_data_counter, fifo_wr_en);
					end if;

					if byte_counter = 128 and sha_512_ready = '1' then
						sha_512_data_valid <= '1';
						round_counter      <= 0;
						byte_counter       <= 0;
						state_sha_wrap     <= hash_new_pk_store;
					end if;

				when hash_new_pk_store =>
					sha_512_data_valid <= '0';
					fifo_wr_en         <= '0';
					if sha_512_finished_wrap = '1' or cache_address_counter /= 0 then
						--public_key_cache      <= sha_512_data_out(511 downto 256);
						cache_address_counter <= cache_address_counter + 1;
						cache_address_b       <= std_logic_vector(to_unsigned(public_key_cache_offset + cache_address_counter, 4));
						cache_data_in_b       <= sha_512_data_out;
						cache_write_b         <= '1';
						if cache_address_counter = 3 then
							state_sha_wrap   <= idle;
							sha_512_finished <= '1';
						end if;
					end if;
				when hash_confirm_start =>
					fifo_wr_en <= '0';
					if message_byte_valid_pipe = '1' then
						--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & message_byte_pipe;
						byte_counter   <= byte_counter + 2;
						state_sha_wrap <= hash_confirm;

						fifo_wr_data <= fifo_wr_data(8 to 63) & message_byte_pipe;
						incr_fifo(fifo_wr_data_counter, fifo_wr_en);
					end if;
				when hash_confirm =>
					sha_512_data_valid <= '0';
					fifo_wr_en         <= '0';
					if message_byte_valid_pipe = '1' then
						--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & message_byte_pipe;
						byte_counter <= byte_counter + 1;

						fifo_wr_data <= fifo_wr_data(8 to 63) & message_byte_pipe;
						incr_fifo(fifo_wr_data_counter, fifo_wr_en);

						if byte_counter = 127 and sha_512_ready = '1' then
							sha_512_n_blocks   <= number_of_rounds_r_enc;
							sha_512_data_valid <= '1';
							byte_counter       <= 0;

							state_sha_wrap <= hash_confirm_final;
						end if;
					end if;
				when hash_confirm_final =>
					sha_512_data_valid <= '0';
					fifo_wr_en         <= '0';
					if message_byte_valid_pipe = '1' and byte_counter /= unpadded_bytes_r_enc then
						--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & message_byte_pipe;
						byte_counter <= byte_counter + 1;

						fifo_wr_data <= fifo_wr_data(8 to 63) & message_byte_pipe;
						incr_fifo(fifo_wr_data_counter, fifo_wr_en);
					end if;

					if byte_counter = unpadded_bytes_r_enc then
						--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & "10000000";
						byte_counter <= byte_counter + 1;

						temp(0)(0)   := '1';
						fifo_wr_data <= fifo_wr_data(8 to 63) & temp;
						incr_fifo(fifo_wr_data_counter, fifo_wr_en);
					end if;

					if byte_counter > unpadded_bytes_r_enc and byte_counter < 112 then
						--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & "00000000";
						byte_counter <= byte_counter + 1;

						temp         := (others => (others => '0'));
						fifo_wr_data <= fifo_wr_data(8 to 63) & temp;
						incr_fifo(fifo_wr_data_counter, fifo_wr_en);
					end if;

					if byte_counter >= 112 and byte_counter < 128 then
						--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & std_logic_vector(to_unsigned(8 * (Small_bytes + 1), 128)((128 - byte_counter) * 8 - 1 downto (127 - byte_counter) * 8));
						byte_counter <= byte_counter + 1;

						temp_vector_128 := t_shared_flatten(small_hash_length_msk, 128);
						--temp_vector_8   := temp_vector_128((128 - to_integer(to_unsigned(byte_counter, 7))) * 8 * shares - 1 downto (127 - to_integer(to_unsigned(byte_counter, 7))) * 8 * shares);
						report "The value of byte_counter is " & integer'image(byte_counter) severity note;
						
						temp_vector_8   := select_range128(temp_vector_128, 127 - to_integer(to_unsigned(byte_counter, 7)));

						fifo_wr_data <= fifo_wr_data(8 to 63) & t_shared_pack(temp_vector_8, 8);
						incr_fifo(fifo_wr_data_counter, fifo_wr_en);
					end if;

					if byte_counter = 128 and sha_512_ready = '1' then
						sha_512_data_valid    <= '1';
						round_counter         <= 0;
						byte_counter          <= 0;
						state_sha_wrap        <= hash_confirm_2;
						cache_address_counter <= 0;
					end if;

				when hash_confirm_2 =>
					sha_512_data_valid <= '0';
					fifo_wr_en         <= '0';

					cache_address_a_fsm <= std_logic_vector(to_unsigned(r_enc_cache_offset, 4));

					if sha_512_finished_wrap = '1' or cache_address_counter /= 0 then

						cache_address_counter <= cache_address_counter + 1;
						cache_address_b       <= std_logic_vector(to_unsigned(r_enc_cache_offset + cache_address_counter, 4));
						cache_data_in_b       <= sha_512_data_out;
						cache_write_b         <= '1';

						if cache_address_counter = 3 then
							cache_address_counter <= 0;
							cache_shift_couter    <= 0;

							if confirm_r_hash_only_pipe = '1' then
								state_sha_wrap   <= idle;
								sha_512_finished <= '1';
							else
								state_sha_wrap                   <= hash_confirm_2_input;
								--fifo_wr_data     <= fifo_wr_data(8 to 63) & "00000010";
								cache_data_out_a_last_byte       <= (others => (others => '0'));
								cache_data_out_a_last_byte(1)(0) <= '1';
								incr_fifo(fifo_wr_data_counter, fifo_wr_en);
								sha_512_n_blocks                 <= 1;
								byte_counter                     <= 1;

								cache_address_a_fsm   <= std_logic_vector(to_unsigned(r_enc_cache_offset + 1, 4));
								cache_address_counter <= 1;
							end if;

						end if;
					end if;
				when hash_confirm_2_input =>
					fifo_wr_en          <= '0';
					cache_address_a_fsm <= std_logic_vector(to_unsigned(r_enc_cache_offset + cache_address_counter + 1, 4));
					cache_write_b       <= '0';
					if byte_counter < 33 then
						byte_counter <= byte_counter + 8;

						fifo_wr_data <= cache_data_out_a_last_byte & cache_data_out_a(63 downto 8);

						cache_data_out_a_last_byte <= cache_data_out_a(7 downto 0);
						fifo_wr_en                 <= '1';

						cache_address_counter <= cache_address_counter + 1;
					end if;

					if byte_counter >= 33 and byte_counter < 65 then
						byte_counter <= byte_counter + 8;

						fifo_wr_data               <= cache_data_out_a_last_byte & cache_data_out_a(63 downto 8);
						cache_data_out_a_last_byte <= cache_data_out_a(7 downto 0);
						fifo_wr_en                 <= '1';

						cache_address_counter <= cache_address_counter + 1;

					end if;

					if byte_counter = 65 then
						byte_counter <= byte_counter + 8;

						fifo_wr_data         <= (others => (others => '0'));
						fifo_wr_data(0 to 7) <= cache_data_out_a_last_byte;
						fifo_wr_data(8)(0)   <= '1';
						--fifo_wr_data <= cache_data_out_a_last_byte & "10000000" & std_logic_vector(to_unsigned(0, 48));
						fifo_wr_en           <= '1';
					end if;

					if byte_counter >= 66 and byte_counter < 112 then
						--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & "00000000";
						byte_counter <= byte_counter + 8;

						fifo_wr_data <= (others => (others => '0'));
						fifo_wr_en   <= '1';
					end if;

					if byte_counter = 113 then
						byte_counter <= byte_counter + 7;

						temp_trans    := (others => (others => '0'));
						temp_trans(0) := std_logic_vector(to_unsigned(8 * 65, 128)((128 - 113) * 8 - 1 downto (120 - 113) * 8));

						fifo_wr_data <= t_shared_trans_to_t_shared(temp_trans);
						temp_trans   := (others => (others => '0'));
						fifo_wr_en   <= '1';
					end if;

					if byte_counter = 120 then
						byte_counter <= byte_counter + 8;

						temp_trans    := (others => (others => '0'));
						temp_trans(0) := std_logic_vector(to_unsigned(8 * 65, 128)((128 - 120) * 8 - 1 downto (120 - 120) * 8));

						fifo_wr_data <= t_shared_trans_to_t_shared(temp_trans);
						temp_trans   := (others => (others => '0'));

						fifo_wr_en <= '1';
					end if;

					if byte_counter = 128 and sha_512_ready = '1' then
						sha_512_data_valid    <= '1';
						state_sha_wrap        <= hash_confirm_2_wait;
						cache_address_counter <= 0;
					end if;
				when hash_confirm_2_wait =>
					sha_512_data_valid <= '0';
					fifo_wr_en         <= '0';
					if sha_512_finished_wrap = '1' or cache_address_counter /= 0 then
						--state_sha_wrap         <= idle;
						cache_address_counter <= cache_address_counter + 1;
						cache_address_b       <= std_logic_vector(to_unsigned(confirm_bytes_cache_offset + cache_address_counter, 4));
						cache_data_in_b       <= sha_512_data_out;
						cache_write_b         <= '1';
						if cache_address_counter = 3 then
							--confirm_bytes    <= sha_512_data_out(511 downto 256);
							--hash_confirm_out_valid <= '1';
							state_sha_wrap   <= idle;
							sha_512_finished <= '1';
						end if;
					end if;
				when hash_session_start =>
					state_sha_wrap <= hash_session_r_enc;
					fifo_wr_en     <= '0';
					if re_encap_session = '1' then
						--sha_512_msg_block_in(767 - 7 to 767) <= std_logic_vector("00000001" + unsigned(diff_mask));

						fifo_wr_data <= fifo_wr_data(8 to 63) & diff_mask;
					else
						--sha_512_msg_block_in(767 - 7 to 767) <= "00000001";

						--fifo_wr_data <= fifo_wr_data(8 to 63) & "00000001"; -- TODO this part is only needed for encap, which is not implemented
					end if;
					--incr_fifo(fifo_wr_data_counter, fifo_wr_en);

					--sha_512_msg_block_in(768 to 1023) <= r_enc_hash;
					byte_counter          <= 1;
					sha_512_n_blocks      <= number_of_rounds_c;
					cache_address_counter <= 0;
					cache_shift_couter    <= 0;
					cache_address_a_fsm   <= std_logic_vector(to_unsigned(r_enc_cache_offset, 4));
				when hash_session_r_enc =>
					fifo_wr_en          <= '0';
					cache_address_a_fsm <= std_logic_vector(to_unsigned(r_enc_cache_offset + cache_address_counter, 4));

					if byte_counter = 32 then
						state_sha_wrap <= hash_session_c;
					end if;

					--fifo_wr_data <= fifo_wr_data(8 to 63) & r_enc_hash((1 - byte_counter) * 8 + 256 - 1 downto (1 - byte_counter) * 8 + 256 - 8);
					temp_vector_64 := t_shared_flatten(cache_data_out_a, 64);
					--temp_vector_8  := temp_vector_64((64 - cache_shift_couter * 8) * shares - 1 downto (64 - cache_shift_couter * 8) * shares - 8 * shares);
					temp_vector_8  := select_range64(temp_vector_64, 7 - cache_shift_couter);
					fifo_wr_data   <= fifo_wr_data(8 to 63) & t_shared_pack(temp_vector_8, 8);
					incr_fifo(fifo_wr_data_counter, fifo_wr_en);

					if cache_shift_couter = 7 then
						cache_shift_couter <= 0;
					else
						cache_shift_couter <= cache_shift_couter + 1;
					end if;

					if cache_shift_couter = 5 then
						cache_address_counter <= cache_address_counter + 1;
					end if;

					byte_counter <= byte_counter + 1;
				when hash_session_c =>
					if fifo_full_next = '1' then
						c_fifo_rd_en <= '0';
					else
						c_fifo_rd_en <= '1';
					end if;

					sha_512_data_valid    <= '0';
					fifo_wr_en            <= '0';
					cache_shift_couter    <= 0;
					cache_address_counter <= 0;
					if message_byte_valid_pipe = '1' then
						--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & message_byte_pipe;
						byte_counter <= byte_counter + 1;

						fifo_wr_data <= fifo_wr_data(8 to 63) & message_byte_pipe;
						incr_fifo(fifo_wr_data_counter, fifo_wr_en);

						if byte_counter >= 127 and sha_512_ready = '1' then
							sha_512_n_blocks   <= number_of_rounds_c;
							sha_512_data_valid <= '1';
							byte_counter       <= byte_counter - 127;
							round_counter      <= round_counter + 1;

							if round_counter = number_of_rounds_c - 2 then
								state_sha_wrap <= hash_session_c_final;
							else
								state_sha_wrap <= hash_session_c;
							end if;
						end if;
					else
						if byte_counter >= 127 and sha_512_ready = '1' then
							sha_512_n_blocks   <= number_of_rounds_c;
							sha_512_data_valid <= '1';
							byte_counter       <= byte_counter - 128;
							round_counter      <= round_counter + 1;

							if round_counter = number_of_rounds_c - 2 then
								state_sha_wrap <= hash_session_c_final;
							else
								state_sha_wrap <= hash_session_c;
							end if;
						end if;
					end if;
				when hash_session_c_final =>
					sha_512_data_valid  <= '0';
					fifo_wr_en          <= '0';
					cache_address_a_fsm <= std_logic_vector(to_unsigned(confirm_bytes_cache_offset + cache_address_counter, 4));

					if re_encap_session = '1' then
						if message_byte_valid_pipe = '1' and byte_counter < unpadded_bytes_c then
							--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & message_byte_pipe;
							byte_counter <= byte_counter + 1;

							fifo_wr_data <= fifo_wr_data(8 to 63) & message_byte_pipe;
							incr_fifo(fifo_wr_data_counter, fifo_wr_en);
						end if;
					else
						if message_byte_valid_pipe = '1' and byte_counter <= unpadded_bytes_c - 32 then
							--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & message_byte_pipe;
							byte_counter <= byte_counter + 1;

							fifo_wr_data <= fifo_wr_data(8 to 63) & message_byte_pipe;
							incr_fifo(fifo_wr_data_counter, fifo_wr_en);
						end if;

						if byte_counter >= unpadded_bytes_c - 32 and byte_counter < unpadded_bytes_c and re_encap_session = '0' and hash_out_read_enable = '0' then
							--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & confirm_bytes((16 - byte_counter) * 8 + 256 - 1 downto (16 - byte_counter) * 8 + 256 - 8);
							byte_counter <= byte_counter + 1;

							--fifo_wr_data <= fifo_wr_data(8 to 63) & confirm_bytes((16 - byte_counter) * 8 + 256 - 1 downto (16 - byte_counter) * 8 + 256 - 8);
							fifo_wr_data <= fifo_wr_data(8 to 63) & t_shared_pack(t_shared_flatten(cache_data_out_a, 64)((64 - cache_shift_couter * 8) * shares - 1 downto (64 - cache_shift_couter * 8) * shares - 8 * shares), 8);
							incr_fifo(fifo_wr_data_counter, fifo_wr_en);

							if cache_shift_couter = 7 then
								cache_shift_couter <= 0;
							else
								cache_shift_couter <= cache_shift_couter + 1;
							end if;

							if cache_shift_couter = 5 then
								cache_address_counter <= cache_address_counter + 1;
							end if;
						end if;
					end if;

					if byte_counter = unpadded_bytes_c then
						--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & "10000000";
						byte_counter <= byte_counter + 1;

						temp(0)(0)   := '1';
						fifo_wr_data <= fifo_wr_data(8 to 63) & temp;
						incr_fifo(fifo_wr_data_counter, fifo_wr_en);
					end if;

					if byte_counter > unpadded_bytes_c and byte_counter < 112 then
						--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & "00000000";
						byte_counter <= byte_counter + 1;

						temp         := (others => (others => '0'));
						fifo_wr_data <= fifo_wr_data(8 to 63) & temp;
						incr_fifo(fifo_wr_data_counter, fifo_wr_en);
					end if;

					if byte_counter >= 112 and byte_counter < 128 then
						--sha_512_msg_block_in <= sha_512_msg_block_in(8 to 1023) & std_logic_vector(to_unsigned(8 * (Ciphertexts_bytes + 32 * 2 + 1), 128)((128 - byte_counter) * 8 - 1 downto (127 - byte_counter) * 8));
						byte_counter <= byte_counter + 1;

						temp_vector_128 := t_shared_flatten(cipher_hash_length_msk, 128);
						--temp_vector_8   := temp_vector_128((128 - byte_counter) * 8 * shares - 1 downto (127 - byte_counter) * 8 * shares);
						temp_vector_8   := select_range128(temp_vector_128, 127 - to_integer(to_unsigned(byte_counter, 7)));
						fifo_wr_data    <= fifo_wr_data(8 to 63) & t_shared_pack(temp_vector_8, 8);
						incr_fifo(fifo_wr_data_counter, fifo_wr_en);
					end if;

					if sha_512_ready = '1' and byte_counter = 128 then
						state_sha_wrap <= hash_session_c_wait;

						sha_512_data_valid    <= '1';
						round_counter         <= 0;
						byte_counter          <= 0;
						cache_address_counter <= 0;
					end if;
				when hash_session_c_wait =>
					if sha_512_finished_wrap = '1' or cache_address_counter /= 0 then
						cache_address_counter <= cache_address_counter + 1;
						cache_address_b       <= std_logic_vector(to_unsigned(sha_out_cache_offset + cache_address_counter, 4));
						cache_data_in_b       <= sha_512_data_out;
						cache_write_b         <= '1';
						if cache_address_counter = 3 then
							state_sha_wrap   <= idle;
							sha_512_finished <= '1';
						end if;
					end if;
					sha_512_data_valid <= '0';
					fifo_wr_en         <= '0';
					c_fifo_rd_en       <= '0';
			end case;

		end if;

		temp            := (others => (others => '0'));
		temp_trans      := (others => (others => '0'));
		temp_vector_8   := (others => '0');
		temp_vector_64  := (others => '0');
		temp_vector_128 := (others => '0');
	end process hash_process;

	sha_512_rand_in <= rand_in;

	public_key_in_valid <= decode_Rq_input_ack and decode_Rq_input_valid;

	message_byte <= public_key_in when state_sha_wrap = hash_new_pk_start or state_sha_wrap = hash_new_pk or state_sha_wrap = hash_new_pk_final
	                else r_encoded_in when state_sha_wrap = hash_confirm_start or state_sha_wrap = hash_confirm or state_sha_wrap = hash_confirm_final
	                else c_fifo_rd_data_msk;

	message_byte_valid <= public_key_in_valid when state_sha_wrap = hash_new_pk_start or state_sha_wrap = hash_new_pk or state_sha_wrap = hash_new_pk_final
	                      else r_encoded_in_valid when state_sha_wrap = hash_confirm_start or state_sha_wrap = hash_confirm or state_sha_wrap = hash_confirm_final
	                      else c_fifo_rd_valid;

	message_byte_pipe       <= message_byte when rising_edge(clock);
	message_byte_valid_pipe <= message_byte_valid when rising_edge(clock);

	sha_512_hash_out <= cache_data_out_a;

	ack_new_input <= '1' when ((byte_counter /= 127 and byte_counter /= 126) or sha_512_ready = '1') and state_sha_wrap /= hash_session_r_enc else '0';

	cache_address_a <= std_logic_vector(sha_out_cache_offset + resize(unsigned(hash_out_address), 4)) when hash_out_read_enable = '1' and hash_out_read_pub_key = '0' and hash_out_read_confirm = '0'
	                   else std_logic_vector(public_key_cache_offset + resize(unsigned(hash_out_address), 4)) when hash_out_read_enable = '1' and hash_out_read_pub_key = '1'
	                   else std_logic_vector(confirm_bytes_cache_offset + resize(unsigned(hash_out_address), 4)) when hash_out_read_enable = '1' and hash_out_read_confirm = '1'
	                   else cache_address_a_fsm;

	confirm_r_hash_only_pipe <= confirm_r_hash_only when rising_edge(clock);

	sha_512_core_msk_inst : entity work.sha_512_core_msk
		generic map(
			RESET_VALUE => '1'
		)
		port map(
			clock              => clock,
			reset              => reset,
			data_ready         => sha_512_data_valid,
			n_blocks           => sha_512_n_blocks,
			read_msg_fifo_en   => fifo_rd_en,
			read_msg_fifo_data => fifo_rd_data,
			rand_in            => sha_512_rand_in,
			ready              => sha_512_ready,
			finished           => sha_512_finished_wrap,
			data_out           => sha_512_data_out
		);

	FIFO_buffer_inst : entity work.FIFO_buffer_msk
		generic map(
			RAM_WIDTH => 64,
			RAM_DEPTH => 32
		)
		port map(
			clock      => clock,
			reset      => reset,
			wr_en      => fifo_wr_en,
			wr_data    => fifo_wr_data,
			rd_en      => fifo_rd_en,
			rd_valid   => fifo_rd_valid,
			rd_data    => fifo_rd_data,
			empty      => fifo_empty,
			empty_next => fifo_empty_next,
			full       => fifo_full,
			full_next  => fifo_full_next
		);

	ram_msk_inst : entity work.ram_msk
		generic map(
			ADDRESS_WIDTH => 4,
			DATA_WIDTH    => 64
		)
		port map(
			clock      => clock,
			address_a  => cache_address_a,
			write_a    => '0',
			data_in_a  => (others => (others => '0')),
			data_out_a => cache_data_out_a,
			address_b  => cache_address_b,
			write_b    => cache_write_b,
			data_in_b  => cache_data_in_b,
			data_out_b => open
		);

	dummy_msk_length_and_fifo_data : process(c_fifo_rd_data, pk_cache_in) is
	begin
		c_fifo_rd_data_msk <= (others => (others => '0'));
		pk_cache_in_msk    <= (others => (others => '0'));
		for i in 0 to 7 loop
			c_fifo_rd_data_msk(i)(0) <= c_fifo_rd_data(i);
			pk_cache_in_msk(i)(0)    <= pk_cache_in(i);
		end loop;
	end process dummy_msk_length_and_fifo_data;

	FIFO_c_buffer_inst : entity work.FIFO_buffer
		generic map(
			RAM_WIDTH => 8,
			RAM_DEPTH => 768
		)
		port map(
			clock      => clock,
			reset      => reset,
			wr_en      => c_encoded_in_valid,
			wr_data    => c_encoded_in,
			rd_en      => c_fifo_rd_en,
			rd_valid   => c_fifo_rd_valid,
			rd_data    => c_fifo_rd_data,
			empty      => c_fifo_empty,
			empty_next => c_fifo_empty_next,
			full       => c_fifo_full,
			full_next  => c_fifo_full_next
		);

end architecture RTL;
