--
--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		 constants, and functions 
--
--   To use any of the example code shown below, uncomment the lines and modify as necessary
--

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;
use IEEE.math_real.all;

use work.constants.all;
use work.data_type.all;

package interfaces_32_ska is

	------------
	--constant shares : integer := 3;
	constant width  : natural := 14;

	------------

	type share_num_type is array (width - 1 downto 0) of natural;

	--type t_shared is array (natural range <>) of std_logic_vector(shares - 1 downto 0);

	type t_shared_trans is array (shares - 1 downto 0) of std_logic_vector(width - 1 downto 0);

	function t_shared_trans_to_t_shared(shared_in_trans : in t_shared_trans) return t_shared;
	function t_shared_to_t_shared_trans(shared_in : in t_shared) return t_shared_trans;

	constant level_rand_requirement : natural := get_rand_req(width, 4);
	constant adder64_rand_requirement : natural := get_rand_req(64, 6);

end interfaces_32_ska;

package body interfaces_32_ska is

	function t_shared_trans_to_t_shared(shared_in_trans : in t_shared_trans) return t_shared is
		variable t_shared_out : t_shared(width - 1 downto 0);
	begin
		for I in 0 to width - 1 loop
			for J in 0 to shares - 1 loop
				t_shared_out(I)(J) := shared_in_trans(J)(I);
			end loop;
		end loop;
		return (t_shared_out);
	end t_shared_trans_to_t_shared;

	function t_shared_to_t_shared_trans(shared_in : in t_shared) return t_shared_trans is
		variable t_shared_trans_out : t_shared_trans;
	begin
		for I in 0 to width - 1 loop
			for J in 0 to shares - 1 loop
				t_shared_trans_out(J)(I) := shared_in(I)(J);
			end loop;
		end loop;
		return (t_shared_trans_out);
	end t_shared_to_t_shared_trans;

end interfaces_32_ska;
