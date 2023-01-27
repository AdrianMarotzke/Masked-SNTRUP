library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;

-- This package contains all common data types and functions that are need across modules
package data_type is
	type t_shared is array (natural range <>) of std_logic_vector(shares - 1 downto 0);

	subtype t_shared_bit IS std_logic_vector(shares - 1 downto 0);
	subtype t_rand IS std_logic_vector(and_pini_mul_nrnd - 1 downto 0);
	
	-- flatten and pack t_shared variables to and from std_logic_vectors
	function t_shared_flatten(param : t_shared; width : integer) return std_logic_vector;
	function t_shared_pack(param : std_logic_vector; width : integer) return t_shared;
	function get_rand_LF(rand_in : in std_logic_vector; width : in natural; level : in natural; offset : in natural; PorG : string) return std_logic_vector;
		
	type sha_record_in_type is record
		new_public_key        : std_logic;
		public_key_in         : std_logic_vector(7 downto 0);
		public_key_ready      : std_logic;
		new_pk_cache          : std_logic;
		pk_cache_in           : std_logic_vector(7 downto 0);
		pk_cache_in_valid     : std_logic;
		start_confirm         : std_logic;
		r_encoded_in          : std_logic_vector(7 downto 0);
		r_encoded_in_valid    : std_logic;
		start_session         : std_logic;
		re_encap_session      : std_logic;
		diff_mask             : std_logic_vector(7 downto 0);
		c_encoded_in          : std_logic_vector(7 downto 0);
		c_encoded_in_valid    : std_logic;
		decode_Rq_input_ack   : std_logic;
		decode_Rq_input_valid : std_logic;
		hash_out_address      : std_logic_vector(1 downto 0);
		hash_out_read_en      : std_logic;
		hash_out_read_pub_key : std_logic;
		hash_out_read_confirm : std_logic;
	end record sha_record_in_type;
	type sha_record_out_type is record
		hash_finished      : std_logic;
		hash_ack_new_input : std_logic;
		hash_out           : std_logic_vector(64 - 1 downto 0);
	end record sha_record_out_type;
	
	type sha_record_in_msk_type is record
		new_public_key        : std_logic;
		public_key_in         : t_shared(7 downto 0);
		public_key_ready      : std_logic;
		new_pk_cache          : std_logic;
		pk_cache_in           : std_logic_vector(7 downto 0);
		pk_cache_in_valid     : std_logic;
		start_confirm         : std_logic;
		confirm_r_hash_only   : std_logic;
		r_encoded_in          : t_shared(7 downto 0);
		r_encoded_in_valid    : std_logic;
		start_session         : std_logic;
		re_encap_session      : std_logic;
		diff_mask             : t_shared(7 downto 0);
		c_encoded_in          : std_logic_vector(7 downto 0);
		c_encoded_in_valid    : std_logic;
		decode_Rq_input_ack   : std_logic;
		decode_Rq_input_valid : std_logic;
		hash_out_address      : std_logic_vector(1 downto 0);
		hash_out_read_en      : std_logic;
		hash_out_read_pub_key : std_logic;
		hash_out_read_confirm : std_logic;
	end record sha_record_in_msk_type;
	type sha_record_out_msk_type is record
		hash_finished      : std_logic;
		hash_ack_new_input : std_logic;
		hash_out           : t_shared(64 - 1 downto 0);
	end record sha_record_out_msk_type;

	type decode_Rq_in_type is record
		start          : std_logic;
		input          : std_logic_vector(7 downto 0);
		write_address  : std_logic_vector(Cipher_bytes_bits - 1 downto 0);
		input_valid    : std_logic;
		rounded_decode : std_logic;
	end record decode_Rq_in_type;

	type decode_Rq_out_type is record
		read_address : std_logic_vector(Cipher_bytes_bits - 1 downto 0);
		input_ack    : std_logic;
		output       : std_logic_vector(q_num_bits - 1 downto 0);
		output_valid : std_logic;
		done         : std_logic;
	end record decode_Rq_out_type;

	type encode_Rq_in_type is record
		start       : std_logic;
		input       : std_logic_vector(q_num_bits - 1 downto 0);
		input_valid : std_logic;
		m_input     : std_logic_vector(15 downto 0);
	end record encode_Rq_in_type;

	type encode_Rq_out_type is record
		input_ack    : std_logic;
		output       : std_logic_vector(7 downto 0);
		output_valid : std_logic;
		done         : std_logic;
		read_address : std_logic_vector(p_num_bits - 1 downto 0);
	end record encode_Rq_out_type;

	constant encode_Rq_out_constant_zero : encode_Rq_out_type := ('0', (others => '0'), '0', '0', (others => '0'));

	type encap_core_in_type is record
		start_encap         : std_logic;
		new_public_key      : std_logic;
		public_key_in       : std_logic_vector(q_num_bits - 1 downto 0);
		public_key_valid    : std_logic;

		small_weights_out   : std_logic_vector(1 downto 0);
		small_weights_valid : std_logic;
		small_weights_done  : std_logic;
	end record encap_core_in_type;

	type encap_core_out_type is record
		ready                       : std_logic;
		done                        : std_logic;

		public_key_ready            : std_logic;
		c_encrypt                   : std_logic_vector(q_num_bits - 1 downto 0);
		c_encrypt_valid             : std_logic;
		r_secret                    : std_logic_vector(1 downto 0);
		r_secret_valid              : std_logic;
		small_weights_start         : std_logic;
		small_weights_output_enable : std_logic;
	end record encap_core_out_type;
	
	type encap_core_msk_in_type is record
		start_encap         : std_logic;
		new_public_key      : std_logic;
		public_key_in       : std_logic_vector(q_num_bits - 1 downto 0);
		public_key_valid    : std_logic;

		short_weights_in   : t_shared(1 downto 0);
		short_weights_valid : std_logic;
		short_weights_done  : std_logic;
	end record encap_core_msk_in_type;

	type encap_core_msk_out_type is record
		ready                       : std_logic;
		done                        : std_logic;

		public_key_ready            : std_logic;
		c_encrypt                   : t_shared(q_num_bits - 1 downto 0);
		c_encrypt_valid             : std_logic;
		r_secret                    : t_shared(1 downto 0);
		r_secret_valid              : std_logic;
		short_weights_start         : std_logic;
		short_weights_output_enable : std_logic;
	end record encap_core_msk_out_type;

	type rq_multiplication_in_type is record
		start             : std_logic;
		output_ack        : std_logic;  -- Unused
		bram_f_data_out_a : std_logic_vector(q_num_bits - 1 downto 0);
		bram_f_data_out_b : std_logic_vector(q_num_bits - 1 downto 0);
		bram_g_data_out_a : std_logic_vector(2 - 1 downto 0);
		bram_g_data_out_b : std_logic_vector(2 - 1 downto 0);
		load_small_g      : std_logic;
	end record rq_multiplication_in_type;

	type rq_multiplication_out_type is record
		ready            : std_logic;
		output_valid     : std_logic;
		output           : std_logic_vector(q_num_bits - 1 downto 0);
		done             : std_logic;
		bram_f_address_a : std_logic_vector(p_num_bits - 1 downto 0);
		bram_f_address_b : std_logic_vector(p_num_bits - 1 downto 0);
		bram_g_address_a : std_logic_vector(p_num_bits - 1 downto 0);
		bram_g_address_b : std_logic_vector(p_num_bits - 1 downto 0);
	end record rq_multiplication_out_type;

	type rq_mult_msk_in_type is record
		start           : std_logic;
		output_ack      : std_logic;    -- Unused
		bram_f_data_out : std_logic_vector(q_num_bits - 1 downto 0);
		bram_g_data_out : t_shared(2 - 1 downto 0);
		load_f          : std_logic;
	end record rq_mult_msk_in_type;

	type rq_mult_msk_out_type is record
		ready            : std_logic;
		output_valid     : std_logic;
		output           : t_shared(q_num_bits - 1 downto 0);
		output_greater_0 : t_shared(0 downto 0);
		done             : std_logic;
		bram_f_address   : std_logic_vector(p_num_bits - 1 downto 0);
		bram_g_address   : std_logic_vector(p_num_bits - 1 downto 0);
	end record rq_mult_msk_out_type;

	type decrypt_msk_in_type is record
		start         : std_logic;
		key_ready     : std_logic;
		ginv_data_out : t_shared(1 downto 0);
		f_data_out    : t_shared(1 downto 0);
		c_data_out    : std_logic_vector(q_num_bits - 1 downto 0);
	end record decrypt_msk_in_type;

	type decrypt_msk_out_type is record
		done         : std_logic;
		output_valid : std_logic;
		output       : t_shared(1 downto 0);
		ginv_address : std_logic_vector(p_num_bits - 1 downto 0);
		f_address    : std_logic_vector(p_num_bits - 1 downto 0);
		c_address    : std_logic_vector(p_num_bits - 1 downto 0);

	end record decrypt_msk_out_type;

	type small_random_weights_in_type is record
		start         : std_logic;
		output_enable : std_logic;
		random_output : std_logic_vector(31 downto 0);
	end record small_random_weights_in_type;

	type small_random_weights_out_type is record
		small_weights_valid : std_logic;
		small_weights_out   : signed(1 downto 0);
		done                : std_logic;
		random_enable       : std_logic;
	end record small_random_weights_out_type;

	type mod3_freeze_round_in_type is record
		input  : signed(q_num_bits - 1 downto 0);
		enable : std_logic;
	end record mod3_freeze_round_in_type;

	type mod3_freeze_round_out_type is record
		output         : signed(1 downto 0);
		output_rounded : signed(q_num_bits - 1 downto 0);
		output_valid   : std_logic;
	end record mod3_freeze_round_out_type;

	type mult_ram_address is record
		bram_f_address_a : std_logic_vector(p_num_bits - 1 downto 0);
		bram_f_address_b : std_logic_vector(p_num_bits - 1 downto 0);
		bram_g_address_a : std_logic_vector(p_num_bits - 1 downto 0);
		bram_g_address_b : std_logic_vector(p_num_bits - 1 downto 0);
	end record mult_ram_address;

	type mult_ram_data is record
		f_data_out_a : std_logic_vector(q_num_bits - 1 downto 0);
		f_data_out_b : std_logic_vector(q_num_bits - 1 downto 0);
		g_data_out_a : std_logic_vector(2 - 1 downto 0);
		g_data_out_b : std_logic_vector(2 - 1 downto 0);
	end record mult_ram_data;

	type mult_ram_data_3bit is record
		f_data_out_a : std_logic_vector(q_num_bits - 1 downto 0);
		f_data_out_b : std_logic_vector(q_num_bits - 1 downto 0);
		g_data_out_a : std_logic_vector(3 - 1 downto 0);
		g_data_out_b : std_logic_vector(3 - 1 downto 0);
	end record mult_ram_data_3bit;

	type mult_ram_data_4bit is record
		f_data_out_a : std_logic_vector(q_num_bits - 1 downto 0);
		f_data_out_b : std_logic_vector(q_num_bits - 1 downto 0);
		g_data_out_a : std_logic_vector(4 - 1 downto 0);
		g_data_out_b : std_logic_vector(4 - 1 downto 0);
	end record mult_ram_data_4bit;

	type mult_output is record
		output_low  : std_logic_vector(q_num_bits - 1 downto 0);
		output_mid  : std_logic_vector(q_num_bits - 1 downto 0);
		output_high : std_logic_vector(q_num_bits - 1 downto 0);
	end record mult_output;

	constant mod3_freeze_round_zero : mod3_freeze_round_out_type := ((others => '0'), (others => '0'), '0');

	constant rq_mult_out_type_zero : rq_multiplication_out_type := ('0', '0', (others => '0'), '0', (others => '0'), (others => '0'), (others => '0'), (others => '0'));

	function non_zero_mask(x : signed) return signed;

	function negative_mask(x : signed) return signed;

	type divmod_cmd is (cmd_store_remainder, cmd_store_both, cmd_output_both, cmd_output_r0_only);

	function select_range128(vector_input : std_logic_vector; select_input : integer) return std_logic_vector;
	function select_range64(vector_input : std_logic_vector; select_input : integer) return std_logic_vector;
end package data_type;

package body data_type is

	function select_range128(vector_input : std_logic_vector; select_input : integer)
	return std_logic_vector is
		type temp_var_type is array (15 downto 0) of std_logic_vector(8 * shares - 1 downto 0);
		variable temp_var : temp_var_type;

	begin
		for i in 15 downto 0 loop
			temp_var(i) := vector_input((i + 1) * 8 * shares - 1 downto i * 8 * shares);
		end loop;

		if select_input >= 16 then -- this is needed to prevent simulation bug
			return temp_var(0);
		end if;
		
		report "The value of select_input is " & integer'image(select_input) severity note;
		return temp_var(select_input);
	end function select_range128;

	function select_range64(vector_input : std_logic_vector; select_input : integer)
	return std_logic_vector is
		type temp_var_type is array (7 downto 0) of std_logic_vector(8 * shares - 1 downto 0);
		variable temp_var : temp_var_type;

	begin
		for i in 7 downto 0 loop
			temp_var(i) := vector_input((i + 1) * 8 * shares - 1 downto i * 8 * shares);
		end loop;

		return temp_var(select_input);
	end function select_range64;


	function get_rand_LF(rand_in : in std_logic_vector; width : in natural; level : in natural; offset : in natural; PorG : string) return std_logic_vector is
		variable rand_out : std_logic_vector(nrnd - 1 downto 0);
		variable rand_num : natural := 0;
	begin
		for L in 1 to level loop
			for I in 0 to width - 2 loop
				if I mod 2**L >= 2**(L - 1) then
					if I = offset and L = level and PorG = "G" then
						assert (rand_num+1)*nrnd-1 < rand_in'length report "rand_num out of bounds: " & "Rand_offset= " & integer'image(rand_num) & "L= " & integer'image(level) & "offset= " & integer'image(offset) & " " & PorG severity failure;
						rand_out := rand_in((rand_num + 1) * nrnd - 1 downto rand_num * nrnd);
						--assert false report "Rand_offset= " & integer'image(rand_num) & "L= " & integer'image(level) & "offset= " & integer'image(offset) & " " & PorG severity note;
					end if;
					rand_num := rand_num + 1;

					if I > 2**L then
						if I = offset and L = level and PorG = "P" then
							assert (rand_num+1)*nrnd-1 < rand_in'length report "rand_num out of bounds: " & "Rand_offset= " & integer'image(rand_num) & "L= " & integer'image(level) & "offset= " & integer'image(offset) & " " & PorG severity failure;
							rand_out := rand_in((rand_num + 1) * nrnd - 1 downto rand_num * nrnd);
							--assert false report "Rand_offset= " & integer'image(rand_num) & "L= " & integer'image(level) & "offset= " & integer'image(offset) & " " & PorG severity note;
						end if;
						rand_num := rand_num + 1;
					end if;
				end if;
			end loop;
		end loop;
		return rand_out;
	end function;
	
	function t_shared_flatten(param : t_shared; width : integer)
	return std_logic_vector is
		variable temp : std_logic_vector(width * shares - 1 downto 0);
	begin
		for i in 0 to width - 1 loop
			temp(shares * (i + 1) - 1 downto shares * i) := param(i);
		end loop;

		return temp;
	end function t_shared_flatten;

	function t_shared_pack(param : std_logic_vector; width : integer)
	return t_shared is
		variable temp : t_shared(width - 1 downto 0);
	begin
		for i in 0 to width - 1 loop
			temp(i) := param(shares * (i + 1) - 1 downto shares * i);
		end loop;

		return temp;
	end function t_shared_pack;

	function non_zero_mask(x : signed)
	return signed is
	begin
		if x = to_signed(0, 16) then
			return to_signed(0, 16);
		else
			return to_signed(-1, 16);
		end if;
	end function non_zero_mask;

	function negative_mask(x : signed)
	return signed is
	begin
		if x >= to_signed(0, 16) then
			return to_signed(0, 16);
		else
			return to_signed(-1, 16);
		end if;
	end function negative_mask;
end package body data_type;
