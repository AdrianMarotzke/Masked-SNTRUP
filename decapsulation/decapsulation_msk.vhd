library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;
use work.interfaces_32_ska.all;

-- The decapuslation
entity decapsulation_msk is
	port(
		clock                : in  std_logic;
		reset                : in  std_logic;
		rand_in              : in  std_logic_vector((q_num_bits + 1 + 8) * and_pini_nrnd + 8 * (shares - 1) - 1 downto 0);
		secret_key_in        : in  std_logic_vector(7 downto 0);
		secret_input_address : out std_logic_vector(SecretKey_length_bits - 1 downto 0);
		key_new              : in  std_logic;
		key_is_set           : out std_logic;
		ready                : out std_logic;
		start_decap          : in  std_logic;
		cipher_input         : in  std_logic_vector(7 downto 0);
		cipher_input_address : out std_logic_vector(Cipher_bytes_bits - 1 downto 0);
		k_hash_out           : out std_logic_vector(63 downto 0);
		k_out_valid          : out std_logic;
		done                 : out std_logic;
		to_sha               : out sha_record_in_msk_type;
		from_sha             : in  sha_record_out_msk_type;
		to_decrypt_msk       : out decrypt_msk_in_type;
		from_decrypt_msk     : in  decrypt_msk_out_type;
		to_encode_Rq         : out encode_Rq_in_type;
		from_encode_Rq       : in  encode_Rq_out_type;
		to_encap_core        : out encap_core_msk_in_type;
		from_encap_core      : in  encap_core_msk_out_type;
		reencap_true         : out std_logic;
		from_rq_mult         : in  rq_mult_msk_out_type
	);
end entity decapsulation_msk;

architecture RTL of decapsulation_msk is

	type state_type is (IDLE, LOAD_NEW_SECRET_KEY, LOAD_NEW_SECRET_KEY_DECODE_START, LOAD_NEW_KEY_PK, LOAD_NEW_KEY_PK_2, LOAD_RHO, LOAD_PK_CACHE, KEY_READY,
	                    LOAD_CIPHER_WAIT,
	                    DECRYPT_CORE_START, DECRYPT_CORE, DECAP_CORE_R3, DECRYPT_CORE_WAIT, START_REENCAP, REENCAP, REENCAP_END, REENCAP_DIFF_C, REENCAP_DIFF_HASH, REENCAP_DIFF_DONE,
	                    MASK_R_ENC, MASK_R_ENC_DONE, HASH_SESSION_START, HASH_SESSION, HASH_SESSION_END, OUTPUT_HASH, DONE_STATE
	                   );
	signal state_dec_wrap : state_type;

	type state_type2 is (IDLE_ZX, DECODE_F, DECODE_GINV);
	signal state_Zx : state_type2;

	type state_type3 is (IDLE, LOAD_CIPHER, LOAD_CIPHER_HASH, LOAD_CIPHER_DONE);
	signal state_Rq_cipher : state_type3;

	signal decrypt_start             : std_logic;
	signal decrypt_done              : std_logic;
	signal decrypt_r_output          : t_shared(1 downto 0);
	signal decrypt_r_output_valid    : std_logic;
	signal decrypt_key_ready         : std_logic;
	signal decrypt_ginv_address_a    : std_logic_vector(p_num_bits - 1 downto 0);
	signal decrypt_ginv_data_out_a   : t_shared(1 downto 0);
	signal key_decap_ginv_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal key_decap_ginv_data_out_b : t_shared(1 downto 0);

	signal reencrypt_ready               : std_logic;
	signal reencrypt_done                : std_logic;
	signal reencrypt_start               : std_logic;
	signal reencrypt_new_public_key      : std_logic;
	signal reencrypt_public_key_in       : std_logic_vector(q_num_bits - 1 downto 0);
	signal reencrypt_public_key_valid    : std_logic;
	signal reencrypt_public_key_ready    : std_logic;
	signal reencrypt_c_encrypt           : t_shared(q_num_bits - 1 downto 0);
	signal reencrypt_c_encrypt_valid     : std_logic;
	signal reencrypt_r_secret            : t_shared(1 downto 0);
	signal reencrypt_r_secret_valid      : std_logic;
	signal reencrypt_small_weights_start : std_logic;
	signal reencrypt_small_weights_out   : t_shared(1 downto 0);
	signal reencrypt_small_weights_valid : std_logic;
	signal reencrypt_small_weights_done  : std_logic;

	signal reencrypt_c_encrypt_valid_pipe : std_logic;

	signal bram_ginv_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_ginv_write_a    : std_logic;
	signal bram_ginv_data_in_a  : t_shared(1 downto 0);
	signal bram_ginv_data_out_a : t_shared(1 downto 0);
	signal bram_ginv_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_ginv_write_b    : std_logic;
	signal bram_ginv_data_in_b  : t_shared(1 downto 0);
	signal bram_ginv_data_out_b : t_shared(1 downto 0);

	signal bram_f_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_f_write_a    : std_logic;
	signal bram_f_data_in_a  : t_shared(1 downto 0);
	signal bram_f_data_out_a : t_shared(1 downto 0);
	signal bram_f_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_f_write_b    : std_logic;
	signal bram_f_data_in_b  : t_shared(1 downto 0);
	signal bram_f_data_out_b : t_shared(1 downto 0);

	signal bram_c_address_a   : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_c_write_a     : std_logic;
	signal bram_c_data_in_a   : std_logic_vector(q_num_bits - 1 downto 0);
	signal bram_c_data_out_a  : std_logic_vector(q_num_bits - 1 downto 0);
	signal bram_c_address_b   : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_c_write_b     : std_logic;
	signal bram_c_data_in_b   : std_logic_vector(q_num_bits - 1 downto 0);
	signal bram_c_data_out_b  : std_logic_vector(q_num_bits - 1 downto 0);
	signal c_data_out_b_shift : std_logic_vector(q_num_bits - 1 downto 0);

	signal rq_mult_done : std_logic;

	signal decode_Rq_start        : std_logic;
	signal decode_Rq_input        : std_logic_vector(7 downto 0);
	signal decode_Rq_input_valid  : std_logic;
	signal decode_Rq_input_ack    : std_logic;
	signal decode_rounded_true    : std_logic;
	signal decode_Rq_output       : std_logic_vector(q_num_bits - 1 downto 0);
	signal decode_Rq_output_valid : std_logic;
	signal decode_Rq_done         : std_logic;
	signal decode_Rq_read_address : std_logic_vector(Cipher_bytes_bits - 1 downto 0);

	signal decode_Zx_input        : std_logic_vector(7 downto 0);
	signal decode_Zx_input_valid  : std_logic;
	signal decode_Zx_input_ack    : std_logic;
	signal decode_Zx_output       : std_logic_vector(1 downto 0);
	signal decode_Zx_output_valid : std_logic;
	signal decode_Zx_done         : std_logic;
	signal decode_Zx_start        : std_logic;

	signal counter        : integer range 0 to 2047;
	signal counter_c_diff : integer range 0 to 2047;
	signal counter_c_hash : integer range Ciphertexts_bytes to Ciphertexts_bytes + 32;
	signal counter_decode : integer range 0 to 2047;

	signal counter_pipe : integer range 0 to 2047;

	signal bram_pk_data_in_a : std_logic_vector(q_num_bits - 1 downto 0);

	signal bram_rho_address_a  : std_logic_vector(Small_bytes_bits - 1 downto 0);
	signal bram_rho_write_a    : std_logic;
	signal bram_rho_data_in_a  : t_shared(7 downto 0);
	signal bram_rho_data_out_a : t_shared(7 downto 0);

	signal sha_start_confirm         : std_logic;
	signal sha_confirm_r_hash_only   : std_logic;
	signal sha_r_encoded_in          : t_shared(7 downto 0);
	signal sha_r_encoded_in_valid    : std_logic;
	signal sha_start_session         : std_logic;
	signal sha_c_encoded_in          : std_logic_vector(7 downto 0);
	signal sha_c_encoded_in_valid    : std_logic;
	signal sha_decode_Rq_input_ack   : std_logic;
	signal sha_decode_Rq_input_valid : std_logic;
	signal sha_finished              : std_logic;
	signal sha_ack_new_input         : std_logic;
	signal sha_out                   : t_shared(63 downto 0);
	signal sha_out_flat              : std_logic_vector(64 * shares - 1 downto 0);
	signal sha_out_address           : integer range 0 to 3;
	signal sha_out_read_en           : std_logic;
	signal sha_new_pk_cache          : std_logic;
	signal sha_pk_cache_in           : std_logic_vector(7 downto 0);
	signal sha_pk_cache_in_valid     : std_logic;
	signal sha_re_encap_session      : std_logic;
	signal sha_diff_mask             : t_shared(7 downto 0);

	signal encode_Zx_input        : t_shared(1 downto 0);
	signal encode_Zx_input_valid  : std_logic;
	signal encode_Zx_output       : t_shared(7 downto 0);
	signal encode_Zx_output_valid : std_logic;
	signal encode_Zx_done         : std_logic;

	signal encode_Zx_rnd_input : std_logic_vector(and_pini_mul_nrnd * 4 - 1 downto 0);

	signal encode_Rq_start        : std_logic;
	signal encode_Rq_input        : std_logic_vector(q_num_bits - 1 downto 0);
	signal encode_Rq_input_valid  : std_logic;
	signal encode_Rq_m_input      : std_logic_vector(15 downto 0);
	signal encode_Rq_input_ack    : std_logic;
	signal encode_Rq_output       : std_logic_vector(7 downto 0);
	signal encode_Rq_output_valid : std_logic;
	signal encode_Rq_done         : std_logic;

	signal bram_c_diff_address_a  : std_logic_vector(Cipher_bytes_bits - 1 downto 0);
	signal bram_c_diff_write_a    : std_logic;
	signal bram_c_diff_data_in_a  : std_logic_vector(7 downto 0);
	signal bram_c_diff_data_out_a : std_logic_vector(7 downto 0);

	--signal differentbits : t_shared(15 downto 0);

	signal bram_r_enc_address_a  : std_logic_vector(Small_bytes_bits - 1 downto 0);
	signal bram_r_enc_write_a    : std_logic;
	signal bram_r_enc_data_in_a  : t_shared(7 downto 0);
	signal bram_r_enc_data_out_a : t_shared(7 downto 0);

	signal masked_r_enc             : t_shared(7 downto 0);
	signal masked_r_enc_valid       : std_logic;
	signal masked_r_enc_valid_pipe  : std_logic;
	signal masked_r_enc_valid_pipe2 : std_logic;

	signal c_diff_bram_valid : std_logic;

	signal temp_s_flat : std_logic_vector(8 * shares - 1 downto 0);
	signal temp_s      : t_shared(q_num_bits - 1 downto 0);

	signal sha_record_in  : sha_record_in_msk_type;
	signal sha_record_out : sha_record_out_msk_type;

	signal decrypt_from_rq_mult : rq_mult_msk_out_type;

	signal sha_out_counter : integer range 0 to 7;

	signal decrypt_f_address_a    : std_logic_vector(p_num_bits - 1 downto 0);
	signal decrypt_f_data_out_a   : t_shared(1 downto 0);
	signal key_decap_f_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal key_decap_f_data_out_b : t_shared(1 downto 0);
	signal decrypt_c_address_a    : std_logic_vector(p_num_bits - 1 downto 0);
	signal decrypt_c_data_out_a   : std_logic_vector(q_num_bits - 1 downto 0);
	signal key_decap_c_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal key_decap_c_data_out_b : t_shared(q_num_bits - 1 downto 0);

	signal secret_key_fifo_write_enable : std_logic;
	signal secret_key_fifo_input        : std_logic_vector(8 - 1 downto 0);
	signal secret_key_fifo_read_enable  : std_logic;
	signal secret_key_fifo_output_valid : std_logic;
	signal secret_key_fifo_output       : std_logic_vector(8 - 1 downto 0);
	signal secret_key_fifo_empty        : std_logic;
	signal secret_key_fifo_empty_next   : std_logic;
	signal secret_key_fifo_full         : std_logic;
	signal secret_key_fifo_full_next    : std_logic;

	signal small_bytes_counter : integer range 0 to p;

	signal cipher_input_address_pipe : std_logic_vector(Cipher_bytes_bits - 1 downto 0);

	signal secret_key_valid      : std_logic;
	signal bram_rho_write_a_pipe : std_logic;

	signal decode_cipher_start              : std_logic;
	signal decode_cipher_input              : std_logic_vector(7 downto 0);
	signal decode_cipher_input_read_address : std_logic_vector(Cipher_bytes_bits - 1 downto 0);
	signal decode_cipher_input_valid        : std_logic;
	signal decode_cipher_input_ack          : std_logic;
	signal decode_cipher_output             : std_logic_vector(q_num_bits - 1 downto 0);
	signal cipher_mult3                     : integer;
	signal decode_cipher_output_valid       : std_logic;
	signal decode_cipher_done               : std_logic;

	signal to_decode_Rq   : decode_Rq_in_type;
	signal from_decode_Rq : decode_Rq_out_type;

	signal reencrypt_c_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal reencrypt_c_write_a    : std_logic;
	signal reencrypt_c_data_in_a  : t_shared(q_num_bits - 1 downto 0);
	signal reencrypt_c_data_out_a : t_shared(q_num_bits - 1 downto 0);

	signal r_msk_wr_en    : std_logic;
	signal r_msk_wr_data  : t_shared(2 - 1 downto 0);
	signal r_msk_rd_en    : std_logic;
	signal r_msk_rd_valid : std_logic;
	signal r_msk_rd_data  : t_shared(2 - 1 downto 0);

	signal r_msk_empty      : std_logic;
	signal r_msk_empty_next : std_logic;
	signal r_msk_full       : std_logic;
	signal r_msk_full_next  : std_logic;

	signal cipher_diff_rand_in  : std_logic_vector((q_num_bits + 1) * and_pini_nrnd - 1 downto 0);
	signal start_comparison     : std_logic;
	signal cipher_in_valid      : std_logic;
	signal cipher_in_valid_pipe : std_logic;
	signal cipher_in_a          : t_shared(q_num_bits - 1 downto 0);
	signal cipher_in_b          : std_logic_vector(q_num_bits - 1 downto 0);
	signal cipher_ack           : std_logic;
	signal diff_mask_valid      : std_logic;
	signal diff_mask            : t_shared(7 downto 0);

	signal r_rho_mux_rand_in : std_logic_vector(8 * and_pini_nrnd - 1 downto 0);
	signal out_mux           : std_logic_vector(8 * shares - 1 downto 0);
	signal rho_data_flat     : std_logic_vector(8 * shares - 1 downto 0);
	signal r_data_flat       : std_logic_vector(8 * shares - 1 downto 0);

	signal unmask_k_out     : std_logic;
	signal r_byte_msk_wr_en : std_logic;

	signal r_byte_msk_wr_data    : t_shared(8 - 1 downto 0);
	signal r_byte_msk_rd_en      : std_logic;
	signal r_byte_msk_rd_valid   : std_logic;
	signal r_byte_msk_rd_data    : t_shared(8 - 1 downto 0);
	signal r_byte_msk_empty      : std_logic;
	signal r_byte_msk_empty_next : std_logic;
	signal r_byte_msk_full       : std_logic;
	signal r_byte_msk_full_next  : std_logic;

begin

	decap_wrapper_process : process(clock, reset) is
		variable temp : std_logic_vector(63 downto 0);
	begin
		if reset = '1' then
			state_dec_wrap          <= IDLE;
			ready                   <= '0';
			key_is_set              <= '0';
			decode_Rq_start         <= '0';
			decrypt_start           <= '0';
			reencrypt_start         <= '0';
			sha_new_pk_cache        <= '0';
			sha_start_confirm       <= '0';
			sha_start_session       <= '0';
			sha_re_encap_session    <= '0';
			masked_r_enc_valid_pipe <= '0';
			c_diff_bram_valid       <= '0';
			done                    <= '0';
			sha_out_read_en         <= '0';
			decrypt_key_ready       <= '0';
			decode_Zx_start         <= '0';
			r_msk_rd_en             <= '0';
			secret_key_valid        <= '0';
			cipher_in_valid         <= '0';
			start_comparison        <= '0';
			r_byte_msk_rd_en        <= '0';
		elsif rising_edge(clock) then
			case state_dec_wrap is
				when IDLE =>
					if key_new = '1' then
						state_dec_wrap <= LOAD_NEW_SECRET_KEY;

						--decode_rounded_true <= '0';
						counter <= 0;
					end if;

					ready             <= '1';
					done              <= '0';
					--k_out_valid       <= '0';
					unmask_k_out      <= '0';
					sha_out_read_en   <= '0';
					sha_out_counter   <= 0;
					decrypt_key_ready <= '0';
					secret_key_valid  <= '0';

					cipher_in_valid  <= '0';
					start_comparison <= '0';
					r_byte_msk_rd_en <= '0';

					sha_confirm_r_hash_only <= '0';
				when LOAD_NEW_SECRET_KEY =>
					decode_Zx_start <= '0';
					if secret_key_fifo_empty = '0' then
						state_dec_wrap  <= LOAD_NEW_SECRET_KEY_DECODE_START;
						decode_Zx_start <= '1';
					end if;

					ready <= '0';

					counter          <= counter + 1;
					secret_key_valid <= '1';
				when LOAD_NEW_SECRET_KEY_DECODE_START =>
					decode_Zx_start <= '0';
					counter         <= counter + 1;

					if counter = Small_bytes * 2 - 1 then
						state_dec_wrap  <= LOAD_NEW_KEY_PK;
						decode_Rq_start <= '1';
						counter         <= Small_bytes * 2 + PublicKeys_bytes - 1;

					end if;
				when LOAD_NEW_KEY_PK =>
					counter <= counter - 1;

					if counter = Small_bytes * 2 + p - 1 then
						counter           <= Small_bytes * 2;
						state_dec_wrap    <= LOAD_NEW_KEY_PK_2;
						decrypt_key_ready <= '1';
					end if;

					decode_Rq_start <= '0';
				when LOAD_NEW_KEY_PK_2 =>
					if counter /= Small_bytes * 2 + p then
						counter <= counter + 1;
					end if;

					if decode_Rq_done = '1' then
						state_dec_wrap   <= LOAD_RHO;
						counter          <= Small_bytes * 2 + PublicKeys_bytes;
						sha_new_pk_cache <= '1';
					end if;

					decrypt_key_ready <= '0';
				when LOAD_RHO =>
					counter <= counter + 1;

					if counter = Small_bytes * 2 + PublicKeys_bytes + Small_bytes - 1 then
						state_dec_wrap <= LOAD_PK_CACHE;
					end if;
					sha_new_pk_cache <= '0';
				when LOAD_PK_CACHE =>
					counter <= counter + 1;

					if counter = SecretKey_bytes then
						if state_Rq_cipher = IDLE then
							state_dec_wrap <= KEY_READY;
						else
							state_dec_wrap  <= LOAD_CIPHER_WAIT;
							key_is_set      <= '0';
							sha_out_read_en <= '0';
							sha_out_counter <= 0;
							counter_c_diff  <= 0;
						end if;

						counter          <= 0;
						secret_key_valid <= '0';
					end if;

				when KEY_READY =>
					ready             <= '1';
					key_is_set        <= '1';
					decrypt_key_ready <= '0';

					if start_decap = '1' then
						state_dec_wrap    <= LOAD_CIPHER_WAIT;
						counter_c_diff    <= 0;
						ready             <= '0';
						decrypt_key_ready <= '1';
					end if;

					if key_new = '1' then
						ready             <= '0';
						key_is_set        <= '0';
						state_dec_wrap    <= LOAD_NEW_SECRET_KEY;
						decrypt_key_ready <= '0';
					end if;

					counter         <= 0;
					done            <= '0';
					unmask_k_out    <= '0';
					sha_out_read_en <= '0';
					sha_out_counter <= 0;
				when LOAD_CIPHER_WAIT =>
					decrypt_key_ready <= '0';
					if state_Rq_cipher = LOAD_CIPHER_DONE then
						state_dec_wrap <= DECRYPT_CORE_START;
						counter_c_diff <= 0;
					end if;
				when DECRYPT_CORE_START =>
					state_dec_wrap <= DECRYPT_CORE;
					decrypt_start  <= '1';
					--reencrypt_start   <= '1';
					counter        <= 0;
				when DECRYPT_CORE =>
					if rq_mult_done = '1' then
						state_dec_wrap <= DECRYPT_CORE_WAIT;
					end if;

					decrypt_start     <= '0';
					reencrypt_start   <= '0';
					sha_start_confirm <= '0';
				when DECAP_CORE_R3 =>
					if decrypt_from_rq_mult.done = '1' then
						state_dec_wrap <= DECRYPT_CORE_WAIT;
					end if;
					if encode_Zx_output_valid = '1' then
						counter <= counter + 1;
					end if;
				when DECRYPT_CORE_WAIT =>
					if counter = Small_bytes - 1 then
						state_dec_wrap <= START_REENCAP;
						counter        <= 0;
					end if;

					decrypt_start     <= '0';
					reencrypt_start   <= '0';
					sha_start_confirm <= '0';

					if encode_Zx_output_valid = '1' then
						counter <= counter + 1;
					end if;

					if decrypt_r_output_valid = '1' then
						sha_start_confirm <= '1';
					end if;

					counter_c_diff <= 0;
				when START_REENCAP =>
					sha_start_confirm <= '0';

					if sha_finished = '1' then
						state_dec_wrap  <= REENCAP;
						reencrypt_start <= '1';
						r_msk_rd_en     <= '1';
					end if;
					counter <= p - 1;
				when REENCAP =>
					if reencrypt_c_encrypt_valid = '1' then
						counter <= counter - 1;
					end if;

					if reencrypt_done = '1' then
						state_dec_wrap   <= REENCAP_END;
						counter          <= 0;
						start_comparison <= '1';
					end if;

					reencrypt_start <= '0';
				when REENCAP_END =>
					state_dec_wrap <= REENCAP_DIFF_C;
					r_msk_rd_en    <= '0';

					start_comparison <= '0';
					cipher_in_valid  <= '1';
				when REENCAP_DIFF_C =>
					start_comparison <= '0';
					cipher_in_valid  <= '0';

					if cipher_ack = '1' and counter /= p - 1 then
						counter         <= counter + 1;
						cipher_in_valid <= '1';
					end if;

					cipher_in_valid_pipe <= '0';

					if counter = p - 1 AND cipher_ack = '1' then
						state_dec_wrap       <= REENCAP_DIFF_HASH;
						cipher_in_valid_pipe <= '1';
					end if;

					sha_start_session <= '0';
					sha_out_address   <= 0;
					sha_out_read_en   <= '1';

					counter_c_diff <= Ciphertexts_bytes - 1;
				when REENCAP_DIFF_HASH =>
					if diff_mask_valid = '1' then
						state_dec_wrap  <= REENCAP_DIFF_DONE;
						sha_out_read_en <= '0';
						counter         <= 0;
					end if;

					cipher_in_valid_pipe <= '0';

					if cipher_ack = '1' then
						if sha_out_counter = 7 then
							sha_out_counter <= 0;
						else
							sha_out_counter <= sha_out_counter + 1;
						end if;

						if sha_out_counter = 7 and sha_out_address /= 3 then
							sha_out_address <= sha_out_address + 1;
						end if;

						cipher_in_valid_pipe <= '1';
						counter_c_diff       <= counter_c_diff + 1;
					end if;
					cipher_in_valid <= cipher_in_valid_pipe;
				when REENCAP_DIFF_DONE =>
					state_dec_wrap <= MASK_R_ENC;
					counter        <= 0;
				when MASK_R_ENC =>
					masked_r_enc_valid_pipe <= '1';
					r_byte_msk_rd_en        <= '0';

					if counter = Small_bytes then
						state_dec_wrap          <= MASK_R_ENC_DONE;
						masked_r_enc_valid_pipe <= '0';
						r_byte_msk_rd_en        <= '1';
					end if;

					sha_start_confirm <= '0';

					if counter = Small_bytes - 1 then
						sha_start_confirm       <= '1';
						sha_confirm_r_hash_only <= '1';
					end if;

					counter <= counter + 1;

				when MASK_R_ENC_DONE =>
					masked_r_enc_valid_pipe <= '0';
					sha_start_confirm       <= '0';

					if r_byte_msk_empty = '1' then
						r_byte_msk_rd_en <= '0';
					end if;

					if sha_finished = '1' then
						state_dec_wrap       <= HASH_SESSION_START;
						sha_start_session    <= '1';
						sha_re_encap_session <= '1';
						counter_c_diff       <= 0;

						sha_confirm_r_hash_only <= '0';
					end if;
				when HASH_SESSION_START =>
					state_dec_wrap    <= HASH_SESSION;
					sha_start_session <= '0';
				when HASH_SESSION =>
					if counter_c_diff = Ciphertexts_bytes + 32 - 1 then
						state_dec_wrap <= HASH_SESSION_END;
					end if;

					counter_c_diff    <= counter_c_diff + 1;
					c_diff_bram_valid <= '1';

				when HASH_SESSION_END =>
					c_diff_bram_valid <= '0';
					if sha_finished = '1' then
						state_dec_wrap       <= OUTPUT_HASH;
						sha_re_encap_session <= '0';
						sha_out_read_en      <= '1';
						sha_out_address      <= 0;
					end if;
				when OUTPUT_HASH =>
					if sha_out_address = 3 then
						state_dec_wrap <= DONE_STATE;
					end if;
					sha_out_address <= sha_out_address + 1;
					--k_out_valid     <= '1';
					unmask_k_out    <= '1';
				when DONE_STATE =>
					state_dec_wrap <= KEY_READY;
					done           <= '1';
			end case;
		end if;
	end process decap_wrapper_process;

	secret_input_address <= std_logic_vector(to_unsigned(counter, SecretKey_length_bits)) when state_dec_wrap = LOAD_NEW_SECRET_KEY_DECODE_START --
	                        or state_dec_wrap = LOAD_NEW_SECRET_KEY --
	                        or state_dec_wrap = LOAD_RHO --
	                        or state_dec_wrap = LOAD_PK_CACHE --
	                        or state_dec_wrap = LOAD_NEW_KEY_PK --
	                        or state_dec_wrap = LOAD_NEW_KEY_PK_2 --
	                        else (others => '0');

	secret_key_fifo_input        <= secret_key_in;
	secret_key_fifo_write_enable <= secret_key_valid when (state_dec_wrap = LOAD_NEW_SECRET_KEY or state_dec_wrap = LOAD_NEW_SECRET_KEY_DECODE_START or (decode_Rq_start = '1' and state_dec_wrap = LOAD_NEW_KEY_PK)) and secret_key_fifo_full_next = '0' else '0';

	decode_Zx_input <= secret_key_fifo_output;

	FSM_decode_Zx : process(clock, reset) is
	begin
		if reset = '1' then
			state_Zx              <= IDLE_ZX;
			decode_Zx_input_valid <= '0';
		elsif rising_edge(clock) then
			case state_Zx is
				when IDLE_ZX =>
					if state_dec_wrap = LOAD_NEW_SECRET_KEY then
						state_Zx <= DECODE_F;
					end if;
					small_bytes_counter   <= 0;
					decode_Zx_input_valid <= '0';
				when DECODE_F =>
					if decode_Zx_output_valid = '1' then
						small_bytes_counter <= small_bytes_counter + 1;
					end if;
					decode_Zx_input_valid <= '1';

					if decode_Zx_done = '1' then
						state_Zx              <= DECODE_GINV;
						decode_Zx_input_valid <= '0';
						small_bytes_counter   <= 0;
					end if;
				when DECODE_GINV =>
					if decode_Zx_output_valid = '1' then
						small_bytes_counter <= small_bytes_counter + 1;
					end if;
					decode_Zx_input_valid <= '1';
					if decode_Zx_done = '1' then
						decode_Zx_input_valid <= '0';
						state_Zx              <= IDLE_ZX;
					end if;
			end case;
		end if;
	end process FSM_decode_Zx;

	FSM_process_decode_cipher : process(clock, reset) is
	begin
		if reset = '1' then
			state_Rq_cipher     <= IDLE;
			bram_c_diff_write_a <= '0';
			decode_cipher_start <= '0';
		--key_decap_start     <= '0';
		elsif rising_edge(clock) then
			case state_Rq_cipher is
				when IDLE =>
					decode_rounded_true <= '0';

					if (state_dec_wrap = KEY_READY and start_decap = '1' and (key_new = '0' or seperate_cipher_decode)) or (state_dec_wrap = IDLE and start_decap = '1' and key_new = '1' and seperate_cipher_decode) then
						decode_cipher_start <= '1';
						decode_rounded_true <= '1';

						state_Rq_cipher <= LOAD_CIPHER;
					end if;

					counter_decode <= 0;
				--key_decap_start <= '0';
				when LOAD_CIPHER =>
					bram_c_diff_write_a <= '1';
					decode_cipher_start <= '0';

					if decode_cipher_done = '1' then
						bram_c_diff_write_a <= '0';
						state_Rq_cipher     <= LOAD_CIPHER_HASH;
					end if;

					counter_c_hash <= Ciphertexts_bytes;

					if decode_cipher_output_valid = '1' then
						counter_decode <= counter_decode + 1;
					end if;
				when LOAD_CIPHER_HASH =>
					bram_c_diff_write_a <= '1';

					counter_c_hash <= counter_c_hash + 1;

					if counter_c_hash = Ciphertexts_bytes + 32 - 1 then
						state_Rq_cipher <= LOAD_CIPHER_DONE;
						--key_decap_start <= '1';
					end if;
				when LOAD_CIPHER_DONE =>
					if state_dec_wrap = LOAD_CIPHER_WAIT then
						state_Rq_cipher <= IDLE;
					end if;
					bram_c_diff_write_a <= '0';
					--key_decap_start     <= '0';
			end case;
		end if;
	end process FSM_process_decode_cipher;

	secret_key_fifo_read_enable <= decode_Zx_input_ack;

	decode_Rq_input       <= secret_key_in when state_dec_wrap = LOAD_NEW_KEY_PK or state_dec_wrap = LOAD_NEW_KEY_PK_2 else cipher_input;
	decode_Rq_input_valid <= secret_key_valid when state_dec_wrap = LOAD_NEW_KEY_PK or state_dec_wrap = LOAD_NEW_KEY_PK_2 else '0';

	cipher_input_address <= decode_cipher_input_read_address when state_Rq_cipher = LOAD_CIPHER else std_logic_vector(to_unsigned(counter_c_hash, Cipher_bytes_bits));

	cipher_input_address_pipe <= decode_cipher_input_read_address when rising_edge(clock);

	bram_pk_data_in_a <= std_logic_vector(signed(decode_Rq_output) - q12);

	bram_f_address_a <= std_logic_vector(to_unsigned(small_bytes_counter, p_num_bits)) when state_Zx = DECODE_F else decrypt_f_address_a;

	mask_decode_f_output : process(decode_Zx_output, state_Zx, rand_in) is
		variable temp : std_logic;
	begin
		bram_f_data_in_a <= (others => (others => '0'));

		if state_Zx = DECODE_F then
			bram_f_data_in_a(0)(shares - 1 downto 1) <= rand_in(shares - 2 downto 0);
			bram_f_data_in_a(1)(shares - 1 downto 1) <= rand_in(2 * shares - 3 downto shares - 1);

			temp                   := '0';
			for i in 0 to shares - 2 loop
				temp := temp XOR rand_in(i);
			end loop;
			bram_f_data_in_a(0)(0) <= decode_Zx_output(0) XOR temp;

			temp                   := '0';
			for i in 0 to shares - 2 loop
				temp := temp XOR rand_in(i + shares - 1);
			end loop;
			bram_f_data_in_a(1)(0) <= decode_Zx_output(1) XOR temp;

			temp := '0';
		else
			temp             := '0';
			bram_f_data_in_a <= (others => (others => '0'));
		end if;

	end process mask_decode_f_output;

	bram_f_write_a <= decode_Zx_output_valid when state_Zx = DECODE_F else '0';

	decrypt_f_data_out_a <= bram_f_data_out_a;

	bram_f_address_b       <= key_decap_f_address_b;
	key_decap_f_data_out_b <= bram_f_data_out_b;

	bram_ginv_address_a <= std_logic_vector(to_unsigned(small_bytes_counter, p_num_bits)) when state_Zx = DECODE_GINV else decrypt_ginv_address_a;

	mask_decode_ginv_output : process(decode_Zx_output, rand_in, state_Zx) is
		variable temp : std_logic;
	begin
		bram_ginv_data_in_a <= (others => (others => '0'));

		if state_Zx = DECODE_GINV then
			bram_ginv_data_in_a(0)(shares - 1 downto 1) <= rand_in(shares - 2 downto 0);
			bram_ginv_data_in_a(1)(shares - 1 downto 1) <= rand_in(2 * shares - 3 downto shares - 1);

			temp                      := '0';
			for i in 0 to shares - 2 loop
				temp := temp XOR rand_in(i);
			end loop;
			bram_ginv_data_in_a(0)(0) <= decode_Zx_output(0) XOR temp;

			temp                      := '0';
			for i in 0 to shares - 2 loop
				temp := temp XOR rand_in(i + shares - 1);
			end loop;
			bram_ginv_data_in_a(1)(0) <= decode_Zx_output(1) XOR temp;

			temp := '0';
		else
			temp                := '0';
			bram_ginv_data_in_a <= (others => (others => '0'));
		end if;
	end process mask_decode_ginv_output;

	bram_ginv_write_a       <= decode_Zx_output_valid when state_Zx = DECODE_GINV else '0';
	decrypt_ginv_data_out_a <= bram_ginv_data_out_a;

	bram_ginv_address_b       <= key_decap_ginv_address_b;
	key_decap_ginv_data_out_b <= bram_ginv_data_out_b;

	bram_c_address_a <= std_logic_vector(to_unsigned(counter_decode, p_num_bits)) when state_Rq_cipher = LOAD_CIPHER
	                    else decrypt_c_address_a when state_dec_wrap = DECRYPT_CORE_WAIT or state_dec_wrap = DECRYPT_CORE or state_dec_wrap = DECRYPT_CORE
	                    else from_encode_Rq.read_address;

	bram_c_data_in_a <= std_logic_vector(resize(signed(decode_cipher_output) * 3 - q12, q_num_bits));

	bram_c_write_a <= decode_cipher_output_valid when state_Rq_cipher = LOAD_CIPHER_DONE or state_Rq_cipher = LOAD_CIPHER else '0';

	cipher_mult3 <= to_integer(signed(bram_c_data_out_a)) * 3;

	decrypt_c_data_out_a <= std_logic_vector(to_unsigned(cipher_mult3 - q, q_num_bits)) when cipher_mult3 >= q
	                        else std_logic_vector(to_unsigned(cipher_mult3 + 2 * q, q_num_bits)) when cipher_mult3 < -q
	                        else std_logic_vector(to_unsigned(cipher_mult3 + q, q_num_bits)) when cipher_mult3 < 0
	                        else std_logic_vector(to_unsigned(cipher_mult3, q_num_bits));

	counter_pipe <= counter when rising_edge(clock);

	reencrypt_c_address_a <= std_logic_vector(to_unsigned(counter_pipe, p_num_bits)) when state_dec_wrap = REENCAP
	                         else std_logic_vector(to_unsigned(counter, p_num_bits)) when state_dec_wrap = REENCAP_DIFF_C and cipher_ack = '0'
	                         else std_logic_vector(to_unsigned(counter + 1, p_num_bits)) when state_dec_wrap = REENCAP_DIFF_C and cipher_ack = '1'
	                         else (others => '0');

	reencrypt_c_encrypt_valid_pipe <= reencrypt_c_encrypt_valid when rising_edge(clock);
	reencrypt_c_write_a            <= reencrypt_c_encrypt_valid_pipe when state_dec_wrap = REENCAP else '0';
	reencrypt_c_data_in_a          <= reencrypt_c_encrypt when rising_edge(clock);

	key_decap_c_data_out_b <= reencrypt_c_data_out_a;

	reencrypt_new_public_key   <= key_new;
	reencrypt_public_key_in    <= std_logic_vector(to_unsigned(to_integer(signed(bram_pk_data_in_a)) + q, q_num_bits)) when signed(bram_pk_data_in_a) < 0 else bram_pk_data_in_a;
	reencrypt_public_key_valid <= decode_Rq_output_valid when state_dec_wrap = LOAD_NEW_KEY_PK or state_dec_wrap = LOAD_NEW_KEY_PK_2 else '0';

	reencrypt_small_weights_out   <= r_msk_rd_data;
	reencrypt_small_weights_valid <= r_msk_rd_valid;
	reencrypt_small_weights_done  <= '0';

	bram_rho_address_a <= std_logic_vector(to_unsigned(counter - Small_bytes * 2 - PublicKeys_bytes - 1, Small_bytes_bits)) when state_dec_wrap /= MASK_R_ENC and state_dec_wrap /= REENCAP_DIFF_DONE else std_logic_vector(to_unsigned(counter, Small_bytes_bits));

	mask_rho_output : process(secret_key_in, bram_rho_write_a, rand_in) is
		variable temp  : std_logic;
		variable temp2 : std_logic_vector(shares - 2 downto 0);

	begin
		bram_rho_data_in_a <= (others => (others => '0'));

		if bram_rho_write_a = '1' then
			if shares = 2 then
				for i in 0 to 7 loop
					temp2(0)                 := rand_in(i);
					bram_rho_data_in_a(i)(1) <= temp2(0);
				end loop;
			else
				for i in 0 to 7 loop
					temp2                                      := rand_in((i + 1) * shares - 2 - i downto shares * i - i);
					bram_rho_data_in_a(i)(shares - 1 downto 1) <= temp2;
				end loop;

			end if;

			for j in 0 to 7 loop
				temp := '0';
				for i in 0 to shares - 2 loop
					temp := temp XOR rand_in(i + j * (shares - 1));
				end loop;

				bram_rho_data_in_a(j)(0) <= secret_key_in(j) XOR temp;
			end loop;

			temp := '0';
		else
			temp               := '0';
			bram_rho_data_in_a <= (others => (others => '0'));
		end if;

		temp2 := (others => '0');
	end process mask_rho_output;

	bram_rho_write_a_pipe <= secret_key_valid when state_dec_wrap = LOAD_RHO else '0';

	bram_rho_write_a <= bram_rho_write_a_pipe when rising_edge(clock);

	sha_pk_cache_in       <= secret_key_in when state_dec_wrap = LOAD_PK_CACHE or (counter = Small_bytes - 1 and state_dec_wrap = LOAD_RHO) else (others => '0');
	sha_pk_cache_in_valid <= secret_key_valid when state_dec_wrap = LOAD_PK_CACHE or (counter = Small_bytes - 1 and state_dec_wrap = LOAD_RHO) else '0';

	encode_Zx_input       <= decrypt_r_output;
	encode_Zx_input_valid <= decrypt_r_output_valid;

	r_msk_wr_data <= decrypt_r_output;
	r_msk_wr_en   <= decrypt_r_output_valid;

	mux2_gadget_inst : entity work.mux2_gadget
		generic map(
			d    => shares,
			word => 8
		)
		port map(
			clk     => clock,
			a_input => r_data_flat,
			b_input => rho_data_flat,
			s_input => diff_mask(0),
			rnd     => r_rho_mux_rand_in,
			out_mux => out_mux
		);

	r_rho_mux_rand_in <= rand_in(8 * and_pini_nrnd + 8 * (shares - 1) - 1 downto 8 * (shares - 1));

	rho_data_flat <= t_shared_flatten(bram_rho_data_out_a, 8) when state_dec_wrap = MASK_R_ENC or state_dec_wrap = MASK_R_ENC_DONE else (others => '0');
	r_data_flat   <= t_shared_flatten(bram_r_enc_data_out_a, 8) when state_dec_wrap = MASK_R_ENC or state_dec_wrap = MASK_R_ENC_DONE else (others => '0');

	masked_r_enc <= t_shared_pack(out_mux, 8);

	masked_r_enc_valid_pipe2 <= masked_r_enc_valid_pipe when rising_edge(clock);
	masked_r_enc_valid       <= masked_r_enc_valid_pipe2 when rising_edge(clock);

	r_byte_msk_wr_data <= masked_r_enc;
	r_byte_msk_wr_en   <= masked_r_enc_valid;

	sha_r_encoded_in       <= r_byte_msk_rd_data when state_dec_wrap = MASK_R_ENC or state_dec_wrap = MASK_R_ENC_DONE else encode_Zx_output;
	sha_r_encoded_in_valid <= r_byte_msk_rd_valid when state_dec_wrap = MASK_R_ENC or state_dec_wrap = MASK_R_ENC_DONE else encode_Zx_output_valid;

	sha_c_encoded_in       <= bram_c_diff_data_out_a;
	sha_c_encoded_in_valid <= c_diff_bram_valid;

	sha_diff_mask <= diff_mask when rising_edge(clock) and diff_mask_valid = '1';

	bram_c_diff_address_a <= cipher_input_address_pipe when state_Rq_cipher = LOAD_CIPHER
	                         else std_logic_vector(to_unsigned(counter_c_diff, Cipher_bytes_bits)) when state_dec_wrap = HASH_SESSION
	                         else std_logic_vector(to_unsigned(counter_c_hash - 1, Cipher_bytes_bits)) when state_Rq_cipher = LOAD_CIPHER_HASH or state_Rq_cipher = LOAD_CIPHER_DONE
	                         else std_logic_vector(to_unsigned(counter_c_diff, Cipher_bytes_bits)) when encode_Rq_output_valid = '0' --
	                         else std_logic_vector(to_unsigned(counter_c_diff + 1, Cipher_bytes_bits));

	bram_c_diff_data_in_a <= cipher_input;
	--bram_c_diff_write_a   <= cipher_input_valid when (state_dec_wrap = LOAD_CIPHER) or state_dec_wrap = LOAD_CIPHER_HASH else '0';

	bram_r_enc_address_a <= std_logic_vector(to_unsigned(counter, Small_bytes_bits));
	bram_r_enc_data_in_a <= encode_Zx_output;
	bram_r_enc_write_a   <= encode_Zx_output_valid when state_dec_wrap = DECRYPT_CORE_WAIT else '0';

	unmask_k_output : process(clock) is
		variable temp : std_logic_vector(63 downto 0);
	begin
		if rising_edge(clock) then
			temp        := (others => '0');
			k_out_valid <= '0';
			if (state_dec_wrap = OUTPUT_HASH OR state_dec_wrap = DONE_STATE) and unmask_k_out = '1' then
				for i in 0 to 63 loop
					for j in 0 to shares - 1 loop
						temp(i) := temp(i) XOR sha_out(i)(j);
					end loop;
				end loop;
				k_out_valid <= '1';
			end if;

			k_hash_out(63 downto 0) <= temp;
		end if;
	end process unmask_k_output;

	to_decrypt_msk.start         <= decrypt_start;
	to_decrypt_msk.key_ready     <= decrypt_key_ready;
	to_decrypt_msk.c_data_out    <= decrypt_c_data_out_a;
	to_decrypt_msk.f_data_out    <= decrypt_f_data_out_a;
	to_decrypt_msk.ginv_data_out <= decrypt_ginv_data_out_a;

	decrypt_c_address_a    <= from_decrypt_msk.c_address;
	decrypt_f_address_a    <= from_decrypt_msk.f_address;
	decrypt_ginv_address_a <= from_decrypt_msk.ginv_address;
	decrypt_done           <= from_decrypt_msk.done;
	decrypt_r_output_valid <= from_decrypt_msk.output_valid;
	decrypt_r_output       <= from_decrypt_msk.output;

	to_encap_core.start_encap      <= reencrypt_start;
	to_encap_core.new_public_key   <= reencrypt_new_public_key;
	to_encap_core.public_key_in    <= reencrypt_public_key_in;
	to_encap_core.public_key_valid <= reencrypt_public_key_valid;

	to_encap_core.short_weights_in    <= reencrypt_small_weights_out;
	to_encap_core.short_weights_valid <= reencrypt_small_weights_valid;
	to_encap_core.short_weights_done  <= reencrypt_small_weights_done;

	reencrypt_ready <= from_encap_core.ready;
	reencrypt_done  <= from_encap_core.done;

	reencrypt_public_key_ready    <= from_encap_core.public_key_ready;
	reencrypt_c_encrypt           <= from_encap_core.c_encrypt;
	reencrypt_c_encrypt_valid     <= from_encap_core.c_encrypt_valid;
	reencrypt_r_secret            <= from_encap_core.r_secret;
	reencrypt_r_secret_valid      <= from_encap_core.r_secret_valid;
	reencrypt_small_weights_start <= from_encap_core.short_weights_start;

	reencap_true <= '1' when state_dec_wrap = REENCAP else '0';

	decrypt_from_rq_mult <= from_rq_mult;

	rq_mult_done <= from_rq_mult.done;

	sha_record_in.new_public_key        <= '0';
	sha_record_in.public_key_in         <= (others => (others => '0'));
	sha_record_in.public_key_ready      <= '0';
	sha_record_in.new_pk_cache          <= sha_new_pk_cache;
	sha_record_in.pk_cache_in           <= sha_pk_cache_in;
	sha_record_in.pk_cache_in_valid     <= sha_pk_cache_in_valid when rising_edge(clock);
	sha_record_in.start_confirm         <= sha_start_confirm;
	sha_record_in.confirm_r_hash_only   <= sha_confirm_r_hash_only;
	sha_record_in.r_encoded_in          <= sha_r_encoded_in;
	sha_record_in.r_encoded_in_valid    <= sha_r_encoded_in_valid;
	sha_record_in.start_session         <= sha_start_session;
	sha_record_in.re_encap_session      <= sha_re_encap_session;
	sha_record_in.diff_mask             <= sha_diff_mask;
	sha_record_in.c_encoded_in          <= sha_c_encoded_in;
	sha_record_in.c_encoded_in_valid    <= sha_c_encoded_in_valid;
	sha_record_in.decode_Rq_input_ack   <= decode_Rq_input_ack;
	sha_record_in.decode_Rq_input_valid <= decode_Rq_input_valid;
	sha_record_in.hash_out_address      <= std_logic_vector(to_unsigned(sha_out_address, 2));
	sha_record_in.hash_out_read_en      <= sha_out_read_en;
	sha_record_in.hash_out_read_pub_key <= '0';
	sha_record_in.hash_out_read_confirm <= '1' when state_dec_wrap /= HASH_SESSION_END and state_dec_wrap /= OUTPUT_HASH else '0';

	sha_finished      <= sha_record_out.hash_finished;
	sha_ack_new_input <= sha_record_out.hash_ack_new_input;
	sha_out           <= sha_record_out.hash_out;

	to_sha         <= sha_record_in;
	sha_record_out <= from_sha;

	decode_cipher_input <= cipher_input;

	decode_cipher_input_valid <= '0';

	to_decode_Rq.input          <= decode_Rq_input;
	to_decode_Rq.input_valid    <= decode_Rq_input_valid;
	to_decode_Rq.rounded_decode <= decode_rounded_true;

	decode_Rq_input_ack    <= from_decode_Rq.input_ack;
	decode_Rq_output       <= from_decode_Rq.output;
	decode_Rq_output_valid <= from_decode_Rq.output_valid;
	decode_Rq_done         <= from_decode_Rq.done;
	decode_Rq_read_address <= from_decode_Rq.read_address;

	to_decode_Rq.write_address <= std_logic_vector(to_unsigned(counter - 2 * Small_bytes, SecretKey_length_bits)) when rising_edge(clock);

	decode_R3_inst : entity work.decode_R3
		port map(
			clock        => clock,
			reset        => reset,
			input        => decode_Zx_input,
			input_valid  => decode_Zx_input_valid,
			input_ack    => decode_Zx_input_ack,
			output       => decode_Zx_output,
			output_valid => decode_Zx_output_valid,
			done         => decode_Zx_done
		);

	to_encode_Rq.input       <= encode_Rq_input;
	to_encode_Rq.input_valid <= encode_Rq_input_valid;
	to_encode_Rq.m_input     <= encode_Rq_m_input;
	to_encode_Rq.start       <= encode_Rq_start;

	encode_Rq_input_ack    <= from_encode_Rq.input_ack;
	encode_Rq_output       <= from_encode_Rq.output;
	encode_Rq_output_valid <= from_encode_Rq.output_valid;
	encode_Rq_done         <= from_encode_Rq.done;

	encode_R3_msk_inst : entity work.encode_R3_msk
		port map(
			clock        => clock,
			reset        => reset,
			input        => encode_Zx_input,
			input_valid  => encode_Zx_input_valid,
			rnd_input    => encode_Zx_rnd_input,
			output       => encode_Zx_output,
			output_valid => encode_Zx_output_valid,
			done         => encode_Zx_done
		);

	encode_Zx_rnd_input <= rand_in(4 * and_pini_mul_nrnd - 1 downto 0);

	bram_f_write_b <= '0';

	decode_rp_wrapper_inst : entity work.decode_rp_wrapper
		port map(
			clock               => clock,
			reset               => reset,
			start               => to_decode_Rq.start,
			input               => to_decode_Rq.input,
			input_read_address  => from_decode_Rq.read_address,
			input_write_address => to_decode_Rq.write_address,
			input_valid         => to_decode_Rq.input_valid,
			input_ack           => from_decode_Rq.input_ack,
			rounded_decode      => to_decode_Rq.rounded_decode,
			output              => from_decode_Rq.output,
			output_valid        => from_decode_Rq.output_valid,
			done                => from_decode_Rq.done
		);

	decode_cipher_input_ack          <= from_decode_Rq.input_ack;
	decode_cipher_output             <= from_decode_Rq.output;
	decode_cipher_output_valid       <= from_decode_Rq.output_valid;
	decode_cipher_done               <= from_decode_Rq.done;
	decode_cipher_input_read_address <= from_decode_Rq.read_address;

	to_decode_Rq.start <= decode_Rq_start or decode_cipher_start;

	cipher_comparison_msk_inst : entity work.cipher_comparison_msk
		port map(
			clock            => clock,
			reset            => reset,
			rand_in          => cipher_diff_rand_in,
			start_comparison => start_comparison,
			cipher_in_valid  => cipher_in_valid,
			cipher_in_a      => cipher_in_a,
			cipher_in_b      => cipher_in_b,
			cipher_ack       => cipher_ack,
			diff_mask_valid  => diff_mask_valid,
			diff_mask        => diff_mask
		);

	cipher_diff_rand_in <= rand_in((q_num_bits + 1 + 8) * and_pini_nrnd + 8 * (shares - 1) - 1 downto 8 * and_pini_nrnd + 8 * (shares - 1));

	sha_out_flat <= t_shared_flatten(sha_out, 64);
	--temp_s_flat  <= sha_out_flat(64 * shares - sha_out_counter * 8 * shares - 1 downto 64 * shares - (sha_out_counter + 1) * 8 * shares);
	temp_s_flat  <= select_range64(sha_out_flat, 7 - sha_out_counter);

	temp_s(7 downto 0)              <= t_shared_pack(temp_s_flat, 8);
	temp_s(q_num_bits - 1 downto 8) <= (others => (others => '0'));

	cipher_in_a <= reencrypt_c_data_out_a when state_dec_wrap = REENCAP_DIFF_C
	               else temp_s when state_dec_wrap = REENCAP_DIFF_HASH
	               else (others => (others => '0'));

	cipher_in_b <= c_data_out_b_shift when state_dec_wrap = REENCAP_DIFF_C
	               else std_logic_vector(to_unsigned(0, q_num_bits - 8)) & bram_c_diff_data_out_a when state_dec_wrap = REENCAP_DIFF_HASH -- pad byte of hash with zeros
	               else (others => '0');

	bram_c_address_b <= std_logic_vector(to_unsigned(counter, p_num_bits)) when state_dec_wrap = REENCAP_DIFF_C and cipher_ack = '0'
	                    else std_logic_vector(to_unsigned(counter + 1, p_num_bits)) when state_dec_wrap = REENCAP_DIFF_C and cipher_ack = '1'
	                    else (others => '0');

	c_data_out_b_shift <= std_logic_vector(to_unsigned(to_integer(signed(bram_c_data_out_b)) + q, q_num_bits)) when signed(bram_c_data_out_b) < 0 else bram_c_data_out_b;

	-------------- RAM and memory --------------

	ram_msk_f : entity work.ram_msk
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => 2
		)
		port map(
			clock      => clock,
			address_a  => bram_f_address_a,
			write_a    => bram_f_write_a,
			data_in_a  => bram_f_data_in_a,
			data_out_a => bram_f_data_out_a,
			address_b  => bram_f_address_b,
			write_b    => bram_f_write_b,
			data_in_b  => bram_f_data_in_b,
			data_out_b => bram_f_data_out_b
		);

	bram_ginv_write_b <= '0';

	ram_msk_ginv : entity work.ram_msk
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => 2
		)
		port map(
			clock      => clock,
			address_a  => bram_ginv_address_a,
			write_a    => bram_ginv_write_a,
			data_in_a  => bram_ginv_data_in_a,
			data_out_a => bram_ginv_data_out_a,
			address_b  => bram_ginv_address_b,
			write_b    => bram_ginv_write_b,
			data_in_b  => bram_ginv_data_in_b,
			data_out_b => bram_ginv_data_out_b
		);

	ram_msk_c_reencrypt : entity work.ram_msk
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => q_num_bits
		)
		port map(
			clock      => clock,
			address_a  => reencrypt_c_address_a,
			write_a    => reencrypt_c_write_a,
			data_in_a  => reencrypt_c_data_in_a,
			data_out_a => reencrypt_c_data_out_a,
			address_b  => (others => '0'),
			write_b    => '0',
			data_in_b  => (others => (others => '0')),
			data_out_b => open
		);

	block_ram_inst_c : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => q_num_bits,
			DUAL_PORT     => TRUE
		)
		port map(
			clock      => clock,
			address_a  => bram_c_address_a,
			write_a    => bram_c_write_a,
			data_in_a  => bram_c_data_in_a,
			data_out_a => bram_c_data_out_a,
			address_b  => bram_c_address_b,
			write_b    => '0',
			data_in_b  => (others => '0'),
			data_out_b => bram_c_data_out_b
		);

	block_ram_inst_rand_reject : entity work.ram_msk
		generic map(
			ADDRESS_WIDTH => Small_bytes_bits,
			DATA_WIDTH    => 8
		)
		port map(
			clock      => clock,
			address_a  => bram_rho_address_a,
			write_a    => bram_rho_write_a,
			data_in_a  => bram_rho_data_in_a,
			data_out_a => bram_rho_data_out_a,
			address_b  => (others => '0'),
			write_b    => '0',
			data_in_b  => (others => (others => '0')),
			data_out_b => open
		);

	block_ram_inst_c_diff : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => Cipher_bytes_bits,
			DATA_WIDTH    => 8,
			DUAL_PORT     => FALSE
		)
		port map(
			clock      => clock,
			address_a  => bram_c_diff_address_a,
			write_a    => bram_c_diff_write_a,
			data_in_a  => bram_c_diff_data_in_a,
			data_out_a => bram_c_diff_data_out_a,
			address_b  => (others => '0'),
			write_b    => '0',
			data_in_b  => (others => '0'),
			data_out_b => open
		);

	block_ram_inst_r_enc : entity work.ram_msk
		generic map(
			ADDRESS_WIDTH => Small_bytes_bits,
			DATA_WIDTH    => 8
		)
		port map(
			clock      => clock,
			address_a  => bram_r_enc_address_a,
			write_a    => bram_r_enc_write_a,
			data_in_a  => bram_r_enc_data_in_a,
			data_out_a => bram_r_enc_data_out_a,
			address_b  => (others => '0'),
			write_b    => '0',
			data_in_b  => (others => (others => '0')),
			data_out_b => open
		);

	FIFO_buffer_inst : entity work.FIFO_buffer
		generic map(
			RAM_WIDTH => 8,
			RAM_DEPTH => 382
		)
		port map(
			clock      => clock,
			reset      => reset,
			wr_en      => secret_key_fifo_write_enable,
			wr_data    => secret_key_fifo_input,
			rd_en      => secret_key_fifo_read_enable,
			rd_valid   => secret_key_fifo_output_valid,
			rd_data    => secret_key_fifo_output,
			empty      => secret_key_fifo_empty,
			empty_next => secret_key_fifo_empty_next,
			full       => secret_key_fifo_full,
			full_next  => secret_key_fifo_full_next
		);

	FIFO_buffer_r_msk_inst : entity work.FIFO_buffer_msk
		generic map(
			RAM_WIDTH => 2,
			RAM_DEPTH => p + 1
		)
		port map(
			clock      => clock,
			reset      => reset,
			wr_en      => r_msk_wr_en,
			wr_data    => r_msk_wr_data,
			rd_en      => r_msk_rd_en,
			rd_valid   => r_msk_rd_valid,
			rd_data    => r_msk_rd_data,
			empty      => r_msk_empty,
			empty_next => r_msk_empty_next,
			full       => r_msk_full,
			full_next  => r_msk_full_next
		);

	FIFO_buffer_r_byte_msk_inst : entity work.FIFO_buffer_msk
		generic map(
			RAM_WIDTH => 8,
			RAM_DEPTH => 192
		)
		port map(
			clock      => clock,
			reset      => reset,
			wr_en      => r_byte_msk_wr_en,
			wr_data    => r_byte_msk_wr_data,
			rd_en      => r_byte_msk_rd_en,
			rd_valid   => r_byte_msk_rd_valid,
			rd_data    => r_byte_msk_rd_data,
			empty      => r_byte_msk_empty,
			empty_next => r_byte_msk_empty_next,
			full       => r_byte_msk_full,
			full_next  => r_byte_msk_full_next
		);

end architecture RTL;
