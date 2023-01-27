----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    02:07:08 05/20/2021 
-- Design Name: 
-- Module Name:    LF_level - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use work.constants.all;
use work.data_type.all;
--use work.interfaces_32_ska.all;
-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity LF_level is
	generic(width : natural := 32;
	        level : natural := 1;
	        alg   : string  := "HPC2";
	        rand_in_width : integer := get_rand_req(32, 5));
	Port(clk     : in  STD_LOGIC;
	     G       : in  t_shared(width - 1 downto 0);
	     P       : in  t_shared(width - 1 downto 0);
	     Gdd     : out t_shared(width - 1 downto 0);
	     Pdd     : out t_shared(width - 1 downto 0);
	     rand_in : in  std_logic_vector(rand_in_width-1 downto 0)
	    );
end LF_level;

architecture Behavioral of LF_level is
	COMPONENT MSKxor
		PORT(
			ina   : IN  t_shared_bit;
			inb   : IN  t_shared_bit;
			out_c : OUT t_shared_bit
		);
	END COMPONENT;

	COMPONENT MSKreg
		Generic(d : integer := 2);
		PORT(
			clk   : IN  std_logic;
			in_a  : IN  t_shared_bit;
			out_a : OUT t_shared_bit
		);
	END COMPONENT;

	COMPONENT G0_shared is
		Port(
			clk  : in  STD_LOGIC;
			A    : in  t_shared_bit;
			B    : in  t_shared_bit;
			rand : in  t_rand;
			G    : out t_shared_bit);
	end COMPONENT;

	COMPONENT P0_shared is
		Port(
			--clk : in STD_LOGIC;
			A : in  t_shared_bit;
			B : in  t_shared_bit;
			--rand: in t_rand;
			G : out t_shared_bit);
	end COMPONENT;

	COMPONENT Gi_shared is
		Port(
			clk  : in  STD_LOGIC;
			Gi   : in  t_shared_bit;
			Gj   : in  t_shared_bit;
			Pi   : in  t_shared_bit;
			rand : in  t_rand;
			Gij  : out t_shared_bit);
	end COMPONENT;

	COMPONENT Pi_shared is
		Port(
			clk  : in  STD_LOGIC;
			Pi   : in  t_shared_bit;
			Pj   : in  t_shared_bit;
			rand : in  t_rand;
			Pij  : out t_shared_bit);
	end COMPONENT;

	signal GD, PD : t_shared(width - 1 downto 0);
begin
	
	genHPC2 : if alg = "HPC2" generate
		outerloop : for I in 0 to width - 2 generate -- - 2**(level-1)  generate

			genG : if I mod 2**level >= 2**(level - 1) generate
				signal rand_gi : t_rand;
				signal rand_p  : t_rand;

			begin
				rand_gi <= get_rand_LF(rand_in, width, level, I, "G");

				Gi_X : Gi_shared
					port map(clk, G(I), G(I - (I mod (2 ** (level - 1))) - 1), P(I), rand_gi, Gdd(I));

				genP : if I > 2**level generate
					rand_p  <= get_rand_LF(rand_in, width, level, I, "P");
					
					Pi_X : Pi_shared
						port map(clk, P(I), P(I - (I mod (2 ** (level - 1))) - 1), rand_p, Pdd(I));
				end generate;
			end generate;

			passthrough : if I mod 2**level < 2**(level - 1) generate
				--G passthrough
				GFFidX : MSKreg
					generic map(d => shares)
					port map(clk, G(I), GD(I));
				GFFiddX : MSKreg
					generic map(d => shares)
					port map(clk, GD(I), GDD(I));

				Ppassthrough : if I >= 2**level generate
					--P passthrough
					PFFidX : MSKreg
						generic map(d => shares)
						port map(clk, P(I), PD(I));
					PFFiddX : MSKreg
						generic map(d => shares)
						port map(clk, PD(I), PDD(I));
				end generate;
			end generate;
		end generate outerloop;
	end generate genHPC2;

end Behavioral;

