library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

-- Package for all constants
package constants is

	---------------------------------------------------------------------------------------------------------------------------------------
	-- Configurable constant below
	--------------------------------------------------------------------------------------------------------------------------------------

	constant shares : integer := 2;     -- number of masking shares
	
	---------------------------------------------------------------------------------------------------------------------------------------
	-- Internal constant below
	---------------------------------------------------------------------------------------------------------------------------------------

	type parameter_set_enum is (sntrup653, sntrup761, sntrup857, sntrup953, sntrup1013, sntrup1277);

	constant use_parameter_set : parameter_set_enum := sntrup761; -- only sntrup761 is supported so far

	constant keygen_vector_width : integer := 1; -- Sets vector width of the number of parallel divsteps during key generation

	constant seperate_cipher_decode : boolean := false;

	constant and_pini_mul_nrnd : integer := shares * (shares - 1) / 2;
	constant and_pini_nrnd     : integer := and_pini_mul_nrnd;
	constant nrnd              : integer := and_pini_nrnd;
	
	function get_rand_req(width : in natural; level : in natural) return natural;

	constant keygen_r3_vector_width : integer := 1;

	constant keygen_vector_size : integer := 2**keygen_vector_width;

	constant keygen_r3_vector_size : integer := 2**keygen_r3_vector_width;

	type M_array_Type is array (0 to 41) of integer;

	function set_p return integer;
	function set_q return integer;
	function set_t return integer;
	function set_Rq_bytes return integer;
	function set_Rounded_bytes return integer;
	function set_SecretKey_bytes return integer;

	constant p : integer := set_p;

	constant q : integer := set_q;

	constant t : integer := set_t;

	constant Rq_bytes : integer := set_Rq_bytes;

	constant Rounded_bytes : integer := set_Rounded_bytes;

	constant SecretKey_bytes : integer := set_SecretKey_bytes;

	constant SecretKey_length_bits : integer := integer(ceil(log2(real(SecretKey_bytes))));

	constant PublicKeys_bytes : integer := Rq_bytes;

	constant Ciphertexts_bytes : integer := Rounded_bytes;

	constant ct_with_confirm_bytes : integer := Ciphertexts_bytes + 32;

	constant Cipher_bytes_bits : integer := integer(ceil(log2(real(Ciphertexts_bytes + 32 * 2))));

	constant Small_bytes : integer := ((p + 3) / 4);

	constant Small_bytes_bits : integer := integer(ceil(log2(real(Small_bytes))));

	constant q_num_bits : integer := integer(ceil(log2(real(q))));

	constant p_num_bits : integer := integer(ceil(log2(real(p))));

	constant q_half : integer := integer(ceil(real(q) / real(2)));

	constant q12 : integer := (q - 1) / 2;

	constant decode_div_shift : integer := 31;

	constant max_divdend_width : integer := 14 + decode_div_shift;

	type decode_divisior_type is array (0 to 41) of unsigned(max_divdend_width downto 0);

end package constants;

package body constants is
	-- Setter functions the select the parameters set

	function set_p
	return integer is
	begin
		case use_parameter_set is
			when sntrup653 =>
				return 653;
			when sntrup761 =>
				return 761;
			when sntrup857 =>
				return 857;
			when others => null;
		end case;

		return 761;
	end function set_p;

	function set_q
	return integer is
	begin
		case use_parameter_set is
			when sntrup653 =>
				return 4621;
			when sntrup761 =>
				return 4591;
			when sntrup857 =>
				return 5167;
			when others => null;
		end case;

		return 4591;
	end function set_q;

	function set_t
	return integer is
	begin
		case use_parameter_set is
			when sntrup653 =>
				return 144;
			when sntrup761 =>
				return 143;
			when sntrup857 =>
				return 161;
			when others => null;
		end case;

		return 143;
	end function set_t;

	function set_Rq_bytes
	return integer is
	begin
		case use_parameter_set is
			when sntrup653 =>
				return 994;
			when sntrup761 =>
				return 1158;
			when sntrup857 =>
				return 1322;
			when others => null;
		end case;

		return 1158;
	end function set_Rq_bytes;

	function set_Rounded_bytes
	return integer is
	begin
		case use_parameter_set is
			when sntrup653 =>
				return 865;
			when sntrup761 =>
				return 1007;
			when sntrup857 =>
				return 1152;
			when others => null;
		end case;

		return 1997;
	end function set_Rounded_bytes;

	function set_SecretKey_bytes
	return integer is
	begin
		case use_parameter_set is
			when sntrup653 =>
				return 1518;
			when sntrup761 =>
				return 1763;
			when sntrup857 =>
				return 1999;
			when others => null;
		end case;

		return 1763;
	end function set_SecretKey_bytes;

	function get_rand_req(width : in natural; level : in natural) return natural is
		variable rand_num : natural := 0;
	begin
		for L in 1 to level loop
			for I in 0 to width - 2 loop
				if I mod 2**L >= 2**(L - 1) then
					rand_num := rand_num + 1;

					if I > 2**L then
						rand_num := rand_num + 1;
					end if;
				end if;
			end loop;
		end loop;
		return (rand_num) * nrnd;
	end function;
	
end package body constants;
