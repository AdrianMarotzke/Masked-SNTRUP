library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.math_real.all;

use work.constants.all;
use work.data_type.all;
use work.interfaces_32_ska.all;

entity tb_ntru_top_msk is
end entity tb_ntru_top_msk;

architecture RTL of tb_ntru_top_msk is
	signal clock       : std_logic := '0';
	signal reset       : std_logic := '0';
	signal start_decap : std_logic := '0';
	signal ready       : std_logic;
	signal done        : std_logic;

	constant kat_num : integer := 0;
	function to_std_logic_vector(a : string) return std_logic_vector is
		variable ret : std_logic_vector(a'length * 4 - 1 downto 0);
	begin
		for i in a'range loop
			case a(i) is
				when '0'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "0000";
				when '1'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "0001";
				when '2'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "0010";
				when '3'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "0011";
				when '4'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "0100";
				when '5'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "0101";
				when '6'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "0110";
				when '7'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "0111";
				when '8'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "1000";
				when '9'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "1001";
				when 'A'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "1010";
				when 'B'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "1011";
				when 'C'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "1100";
				when 'D'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "1101";
				when 'E'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "1110";
				when 'F'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "1111";
				when others => null;
			end case;

		end loop;
		return ret;
	end function to_std_logic_vector;

	type mem_type is array (0 to 1024 * 4) of std_logic_vector(7 downto 0);
	signal private_key_ram : mem_type;

	signal cipher_ram : mem_type;

	signal start_key_gen            : std_logic;
	signal start_encap              : std_logic;
	signal set_new_public_key       : std_logic;
	signal public_key_in            : std_logic_vector(7 downto 0);
	signal public_key_input_address : std_logic_vector(Cipher_bytes_bits - 1 downto 0);
	signal public_key_is_set        : std_logic;
	signal set_new_private_key      : std_logic;
	signal private_key_in           : std_logic_vector(7 downto 0);
	signal private_key_in_address   : std_logic_vector(SecretKey_length_bits - 1 downto 0);
	signal private_key_is_set       : std_logic;
	signal cipher_output            : std_logic_vector(7 downto 0);
	signal cipher_output_valid      : std_logic;
	signal cipher_input             : std_logic_vector(7 downto 0);
	signal cipher_input_address     : std_logic_vector(Cipher_bytes_bits - 1 downto 0);
	signal k_hash_out_tb            : std_logic_vector(255 downto 0);	
	signal k_hash_out               : std_logic_vector(63 downto 0);
	signal k_out_valid              : std_logic;
	signal private_key_out          : std_logic_vector(7 downto 0);
	signal private_key_out_valid    : std_logic;
	signal public_key_out           : std_logic_vector(7 downto 0);
	signal public_key_out_valid     : std_logic;
	signal random_roh_enable        : std_logic;
	signal random_roh_output        : std_logic_vector(31 downto 0);
	signal random_small_enable      : std_logic;
	signal random_small_output      : std_logic_vector(31 downto 0);
	signal random_short_enable      : std_logic;
	signal random_short_output      : std_logic_vector(31 downto 0);
	signal rand_in                  : std_logic_vector(7 downto 0);

begin

	clock_gen : process is
	begin
		clock <= not clock;
		wait for 2.5 ns;
	end process clock_gen;

	reset_gen : process is
	begin
		reset <= '1';
		wait for 110 ns;
		wait until rising_edge(clock);
		wait for 1 ns;
		reset <= '0';
		wait;
	end process reset_gen;

	ntru_prime_top_inst : entity work.ntru_prime_top
		port map(
			clock                    => clock,
			reset                    => reset,
			ready                    => ready,
			done                     => done,
			rand_in                  => rand_in,
			start_key_gen            => start_key_gen,
			start_encap              => start_encap,
			start_decap              => start_decap,
			set_new_public_key       => set_new_public_key,
			public_key_in            => public_key_in,
			public_key_input_address => public_key_input_address,
			public_key_is_set        => public_key_is_set,
			set_new_private_key      => set_new_private_key,
			private_key_in           => private_key_in,
			private_key_in_address   => private_key_in_address,
			private_key_is_set       => private_key_is_set,
			cipher_output            => cipher_output,
			cipher_output_valid      => cipher_output_valid,
			cipher_input             => cipher_input,
			cipher_input_address     => cipher_input_address,
			k_hash_out               => k_hash_out,
			k_out_valid              => k_out_valid,
			private_key_out          => private_key_out,
			private_key_out_valid    => private_key_out_valid,
			public_key_out           => public_key_out,
			public_key_out_valid     => public_key_out_valid,
			random_roh_enable        => random_roh_enable,
			random_roh_output        => random_roh_output,
			random_small_enable      => random_small_enable,
			random_small_output      => random_small_output,
			random_short_enable      => random_short_enable,
			random_short_output      => random_short_output
		);

	stimulus_sk : process is
		file read_file    : text;
		variable line_v   : line;
		variable temp8bit : string(1 to 2);
	begin
		file_open(read_file, "./tb_stimulus/KAT_761/sk_tb", read_mode);

		wait until set_new_private_key = '1';
		wait for 1 ns;

		for i in 0 to kat_num loop
			readline(read_file, line_v);
		end loop;

		for i in 0 to SecretKey_bytes - 1 loop
			read(line_v, temp8bit);
			private_key_ram(i) <= to_std_logic_vector(temp8bit);
		end loop;

		file_close(read_file);

	end process stimulus_sk;

	private_key_in <= private_key_ram(to_integer(unsigned(private_key_in_address))) when rising_edge(clock);

	stimulus_c : process is
		file read_file    : text;
		variable line_v   : line;
		variable temp8bit : string(1 to 2);

	begin
		file_open(read_file, "./tb_stimulus/KAT_761/ct_tb", read_mode);

		wait until start_decap = '1';
		wait for 1 ns;

		for i in 0 to kat_num loop
			readline(read_file, line_v);
		end loop;

		for i in 0 to ct_with_confirm_bytes - 1 loop
			read(line_v, temp8bit);
			cipher_ram(i) <= to_std_logic_vector(temp8bit);
		end loop;

		wait until rising_edge(clock) and done = '1';
		file_close(read_file);
	end process stimulus_c;

	cipher_input <= cipher_ram(to_integer(unsigned(cipher_input_address))) when rising_edge(clock);

	stim : process is
	begin
		set_new_private_key <= '0';
		start_decap         <= '0';
		wait for 1000 ns;
		wait until rising_edge(clock);
		wait for 1 ns;
		set_new_private_key <= '1';
		wait until rising_edge(clock);
		wait for 1 ns;
		set_new_private_key <= '0';
		wait until rising_edge(clock) and private_key_is_set = '1';
		wait for 1000 ns;
		wait until rising_edge(clock);
		wait for 1 ns;
		start_decap         <= '1';
		wait until rising_edge(clock);
		wait for 1 ns;
		start_decap         <= '0';

		wait;
	end process stim;

	gen_random : process is
		variable seed1         : positive := 1;
		variable seed2         : positive := 1;
		variable rand          : real;
		constant range_of_rand : real := (2.0)**(8) - 1.0;
	begin
		wait for 1 ns;
		uniform(seed1, seed2, rand);
		rand_in <= std_logic_vector(to_unsigned(integer(rand * range_of_rand), 8));
		wait until rising_edge(clock);
	end process gen_random;

	check_hash_output : process is
		file read_file    : text;
		variable line_v   : line;
		variable temp8bit : string(1 to 64);
	begin
		file_open(read_file, "./tb_stimulus/KAT_761/hash_tb", read_mode);

		wait until k_out_valid = '1';

		for i in 0 to kat_num loop
			readline(read_file, line_v);
		end loop;

		read(line_v, temp8bit);
		k_hash_out_tb <= to_std_logic_vector(temp8bit);

		wait until rising_edge(clock) and k_out_valid = '1';

		assert k_hash_out_tb(255 downto 192) = k_hash_out report "Mismatch in k hash output 0" severity failure;

		wait until rising_edge(clock) and k_out_valid = '1';

		assert k_hash_out_tb(191 downto 128) = k_hash_out report "Mismatch in k hash output 1" severity failure;

		wait until rising_edge(clock) and k_out_valid = '1';

		assert k_hash_out_tb(127 downto 64) = k_hash_out report "Mismatch in k hash output 2" severity failure;

		wait until rising_edge(clock) and k_out_valid = '1';

		assert k_hash_out_tb(63 downto 0) = k_hash_out report "Mismatch in k hash output 3" severity failure;

		file_close(read_file);

		wait until rising_edge(clock);
	end process check_hash_output;
	
	--rand_in <= (others => '0');
end architecture RTL;
