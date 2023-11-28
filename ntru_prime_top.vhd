library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;
use work.interfaces_32_ska.all;

-- Top Module
entity ntru_prime_top is
	port(
		clock                    : in  std_logic;							-- Clock signal
		reset                    : in  std_logic;							-- Active high reset signal
		rand_in                  : in  std_logic_vector(7 downto 0); 		-- Randomness for masking. This is only 8 bit wise to simplifiy the testbench, and should be changed to std_logic_vector(adder64_rand_requirement - 1 downto 0) for proper deployment
		ready                    : out std_logic;							-- Read signal, design can process new commands
		done                     : out std_logic;							-- Output signal indicating operation is complete
		--
		start_key_gen            : in  std_logic;							-- Not used
		start_encap              : in  std_logic;							-- Not used
		--
		start_decap              : in  std_logic;							-- Input signal to start decapsulation. A private key must be set first
		--
		set_new_public_key       : in  std_logic;							-- Not used
		public_key_in            : in  std_logic_vector(7 downto 0);		-- Not used
		public_key_input_address : out std_logic_vector(Cipher_bytes_bits - 1 downto 0);	-- Not used
		public_key_is_set        : out std_logic;							-- Not used
		--
		set_new_private_key      : in  std_logic;							-- Input signal to load a new private key
		private_key_in           : in  std_logic_vector(7 downto 0);		-- Private key input signal
		private_key_in_address   : out std_logic_vector(SecretKey_length_bits - 1 downto 0); -- Private key memory address signal
		private_key_is_set       : out std_logic;							-- Indicates a private key has be input & decoded
		--
		cipher_output            : out std_logic_vector(7 downto 0);		-- Not used
		cipher_output_valid      : out std_logic;							-- Not used
		--
		cipher_input             : in  std_logic_vector(7 downto 0);		-- Ciphertext input signal
		cipher_input_address     : out std_logic_vector(Cipher_bytes_bits - 1 downto 0); -- Ciphertext memory address signal
		--
		k_hash_out               : out std_logic_vector(63 downto 0);		-- Shared secret output signal. This signal is unmasked. Deployments should consider keeping it masked.
		k_out_valid              : out std_logic;							-- Shared secret output valid signal
		--
		private_key_out          : out std_logic_vector(7 downto 0);		-- Not used
		private_key_out_valid    : out std_logic;							-- Not used
		public_key_out           : out std_logic_vector(7 downto 0);		-- Not used
		public_key_out_valid     : out std_logic;							-- Not used
		random_roh_enable        : out std_logic;							-- Not used
		random_roh_output        : in  std_logic_vector(31 downto 0);		-- Not used
		random_small_enable      : out std_logic;							-- Not used
		random_small_output      : in  std_logic_vector(31 downto 0);		-- Not used
		random_short_enable      : out std_logic;							-- Not used
		random_short_output      : in  std_logic_vector(31 downto 0)		-- Not used
	);
end entity ntru_prime_top;

architecture RTL of ntru_prime_top is

	signal to_sha                : sha_record_in_msk_type;
	signal from_sha              : sha_record_out_msk_type;
	signal to_sha_delay          : sha_record_in_msk_type;
	signal from_sha_delay        : sha_record_out_msk_type;
	signal from_encode_Rq        : encode_Rq_out_type;
	signal to_encap_core         : encap_core_msk_in_type;
	signal from_encap_core       : encap_core_msk_out_type;
	signal to_encap_core_delay   : encap_core_msk_in_type;
	signal from_encap_core_delay : encap_core_msk_out_type;
	signal reencap_true          : std_logic;
	signal to_rq_mult_encrypt    : rq_mult_msk_in_type;
	signal from_rq_mult_encrypt  : rq_mult_msk_out_type;
	signal to_rq_mult            : rq_mult_msk_in_type;
	signal from_rq_mult          : rq_mult_msk_out_type;
	signal to_rq_mult_decrypt    : rq_mult_msk_in_type;
	signal from_rq_mult_decrypt  : rq_mult_msk_out_type;
	signal from_freeze_round     : mod3_freeze_round_out_type;

	signal to_decrypt_msk   : decrypt_msk_in_type;
	signal from_decrypt_msk : decrypt_msk_out_type;

	constant from_rq_zero : rq_mult_msk_out_type := ('0', '0', (others => (others => '0')), (others => (others => '0')), '0', (others => '0'), (others => '0'));

	signal decap_rand_in   : std_logic_vector((q_num_bits + 1 + 8) * and_pini_nrnd + 8 * (shares - 1) - 1 downto 0);
	signal decrypt_rand_in : std_logic_vector(and_pini_mul_nrnd * 46 + and_pini_nrnd * 6 + and_pini_nrnd * 2 + level_rand_requirement + and_pini_nrnd * 10 - 1 downto 0);
	signal encrypt_rand_in : std_logic_vector(and_pini_nrnd * q_num_bits + level_rand_requirement * 2 + and_pini_mul_nrnd * 46 - 1 downto 0);
	signal rq_mult_rand_in : std_logic_vector(level_rand_requirement * 2 + and_pini_mul_nrnd * q_num_bits * 3 - 1 downto 0);
	signal sha_rand_in     : std_logic_vector(adder64_rand_requirement - 1 downto 0);

	-- prevent randomness for being optiized in any way
	attribute keep : string;
	attribute DONT_TOUCH  : string;
	attribute MARK_DEBUG   : string;

	attribute keep of decap_rand_in : signal is "true";
	attribute keep of decrypt_rand_in : signal is "true";
	attribute keep of encrypt_rand_in : signal is "true";
	attribute keep of rq_mult_rand_in : signal is "true";
	attribute keep of sha_rand_in : signal is "true";
	
	attribute DONT_TOUCH of decap_rand_in : signal is "true";
	attribute DONT_TOUCH of decrypt_rand_in : signal is "true";
	attribute DONT_TOUCH of encrypt_rand_in : signal is "true";
	attribute DONT_TOUCH of rq_mult_rand_in : signal is "true";
	attribute DONT_TOUCH of sha_rand_in : signal is "true";
	
	attribute MARK_DEBUG of decap_rand_in : signal is "true";
	attribute MARK_DEBUG of decrypt_rand_in : signal is "true";
	attribute MARK_DEBUG of encrypt_rand_in : signal is "true";
	attribute MARK_DEBUG of rq_mult_rand_in : signal is "true";
	attribute MARK_DEBUG of sha_rand_in : signal is "true";
begin

	decapsulation_msk_inst : entity work.decapsulation_msk
		port map(
			clock                => clock,
			reset                => reset,
			rand_in              => decap_rand_in,
			secret_key_in        => private_key_in,
			secret_input_address => private_key_in_address,
			key_new              => set_new_private_key,
			key_is_set           => private_key_is_set,
			ready                => ready,
			start_decap          => start_decap,
			cipher_input         => cipher_input,
			cipher_input_address => cipher_input_address,
			k_hash_out           => k_hash_out,
			k_out_valid          => k_out_valid,
			done                 => done,
			to_sha               => to_sha,
			from_sha             => from_sha,
			to_decrypt_msk       => to_decrypt_msk,
			from_decrypt_msk     => from_decrypt_msk,
			to_encode_Rq         => open,
			from_encode_Rq       => from_encode_Rq,
			to_encap_core        => to_encap_core,
			from_encap_core      => from_encap_core,
			reencap_true         => reencap_true,
			from_rq_mult         => from_rq_mult
		);

	-- This is ok, as no module uses randomness at the same time
	decap_rand_in   <= sha_rand_in((q_num_bits + 1 + 8) * and_pini_nrnd + 8 * (shares - 1) - 1 downto 0);
	decrypt_rand_in <= sha_rand_in(and_pini_mul_nrnd * 46 + and_pini_nrnd * 6 + and_pini_nrnd * 2 + level_rand_requirement + and_pini_nrnd * 10 - 1 downto 0);
	encrypt_rand_in <= sha_rand_in(and_pini_nrnd * q_num_bits + level_rand_requirement * 2 + and_pini_mul_nrnd * 46 - 1 downto 0);
	rq_mult_rand_in <= sha_rand_in(level_rand_requirement * 2 + and_pini_mul_nrnd * q_num_bits * 3 - 1 downto 0);

	-- The following code is to simplify the testbench, and should be removed before deployment
	serial_in_rand : process(clock, reset) is
	begin
		if reset = '1' then
			sha_rand_in <= (others => '0');
		elsif rising_edge(clock) then
			sha_rand_in(adder64_rand_requirement - 1 downto 0) <= sha_rand_in(adder64_rand_requirement - 9 downto 0) & rand_in after 1 ns;
		end if;
	end process serial_in_rand;
	-- Use this instead:
	
	-- sha_rand_in <= rand_in;
	
	-----------------------------------------------------------------------------------------------
	------------------- Shared modules
	-----------------------------------------------------------------------------------------------
	decryption_msk_inst : entity work.decryption_msk
		port map(
			clock         => clock,
			reset         => reset,
			start         => to_decrypt_msk.start,
			done          => from_decrypt_msk.done,
			rnd_input     => decrypt_rand_in,
			output        => from_decrypt_msk.output,
			output_valid  => from_decrypt_msk.output_valid,
			key_ready     => to_decrypt_msk.key_ready,
			ginv_address  => from_decrypt_msk.ginv_address,
			ginv_data_out => to_decrypt_msk.ginv_data_out,
			f_address     => from_decrypt_msk.f_address,
			f_data_out    => to_decrypt_msk.f_data_out,
			c_address     => from_decrypt_msk.c_address,
			c_data_out    => to_decrypt_msk.c_data_out,
			to_rq_mult    => to_rq_mult_decrypt,
			from_rq_mult  => from_rq_mult_decrypt
		);

	to_encap_core_delay <= to_encap_core;
	from_encap_core     <= from_encap_core_delay;

	encrypt_msk_inst : entity work.encrypt_msk
		port map(
			clock                       => clock,
			reset                       => reset,
			ready                       => from_encap_core_delay.ready,
			done                        => from_encap_core_delay.done,
			rand_input                  => encrypt_rand_in,
			start_encap                 => to_encap_core_delay.start_encap,
			new_public_key              => to_encap_core_delay.new_public_key,
			public_key_in               => to_encap_core_delay.public_key_in,
			public_key_valid            => to_encap_core_delay.public_key_valid,
			public_key_ready            => from_encap_core_delay.public_key_ready,
			c_encrypt                   => from_encap_core_delay.c_encrypt,
			c_encrypt_valid             => from_encap_core_delay.c_encrypt_valid,
			r_secret                    => from_encap_core_delay.r_secret,
			r_secret_valid              => from_encap_core_delay.r_secret_valid,
			short_weights_start         => from_encap_core_delay.short_weights_start,
			short_weights_output_enable => from_encap_core_delay.short_weights_output_enable,
			short_weights_in            => to_encap_core_delay.short_weights_in,
			short_weights_valid         => to_encap_core_delay.short_weights_valid,
			to_rq_mult                  => to_rq_mult_encrypt,
			from_rq_mult                => from_rq_mult_encrypt,
			to_freeze_round             => open, -- not used
			from_freeze_round           => from_freeze_round -- not used
		);

	to_rq_mult           <= to_rq_mult_decrypt when reencap_true = '0' else to_rq_mult_encrypt;
	from_rq_mult_decrypt <= from_rq_mult when reencap_true = '0' else from_rq_zero;
	from_rq_mult_encrypt <= from_rq_mult when reencap_true = '1' else from_rq_zero;

	rq_mult_msk_inst : entity work.rq_mult_msk
		port map(
			clock              => clock,
			reset              => reset,
			start_mult         => to_rq_mult.start,
			mult_input_address => from_rq_mult.bram_g_address,
			mult_input         => to_rq_mult.bram_g_data_out,
			output             => from_rq_mult.output,
			output_greater_0   => from_rq_mult.output_greater_0,
			output_valid       => from_rq_mult.output_valid,
			done               => from_rq_mult.done,
			rnd_input          => rq_mult_rand_in,
			load_array_start   => to_rq_mult.load_f,
			load_array_address => from_rq_mult.bram_f_address,
			load_array_input   => to_rq_mult.bram_f_data_out
		);

	to_sha_delay <= to_sha;
	from_sha     <= from_sha_delay;

	sha_512_wrapper_msk_inst : entity work.sha_512_wrapper_msk
		port map(
			clock                 => clock,
			reset                 => reset,
			rand_in               => sha_rand_in,
			new_public_key        => to_sha_delay.new_public_key,
			public_key_in         => to_sha_delay.public_key_in,
			new_pk_cache          => to_sha_delay.new_pk_cache,
			pk_cache_in           => to_sha_delay.pk_cache_in,
			pk_cache_valid        => to_sha_delay.pk_cache_in_valid,
			start_confirm         => to_sha_delay.start_confirm,
			confirm_r_hash_only   => to_sha_delay.confirm_r_hash_only,
			r_encoded_in          => to_sha_delay.r_encoded_in,
			r_encoded_in_valid    => to_sha_delay.r_encoded_in_valid,
			start_session         => to_sha_delay.start_session,
			re_encap_session      => to_sha_delay.re_encap_session,
			diff_mask             => to_sha_delay.diff_mask,
			c_encoded_in          => to_sha_delay.c_encoded_in,
			c_encoded_in_valid    => to_sha_delay.c_encoded_in_valid,
			decode_Rq_input_ack   => to_sha_delay.decode_Rq_input_ack,
			decode_Rq_input_valid => to_sha_delay.decode_Rq_input_valid,
			sha_512_finished      => from_sha_delay.hash_finished,
			ack_new_input         => from_sha_delay.hash_ack_new_input,
			sha_512_hash_out      => from_sha_delay.hash_out,
			hash_out_address      => to_sha_delay.hash_out_address,
			hash_out_read_pub_key => to_sha_delay.hash_out_read_pub_key,
			hash_out_read_confirm => to_sha_delay.hash_out_read_confirm,
			hash_out_read_enable  => to_sha_delay.hash_out_read_en
		);

end architecture RTL;
