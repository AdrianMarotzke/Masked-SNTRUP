----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    20:01:35 05/18/2021 
-- Design Name: 
-- Module Name:    KS_16_unshared - Behavioral 
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
use work.constants.all;
use work.data_type.all;
--use work.interfaces_32_ska.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ska_16 is
	generic(width                  : natural := 14;
	        level_rand_requirement : integer := get_rand_req(14, 4)
	       );
	Port(clk     : in  std_logic;
	     A       : in  t_shared(width - 1 downto 0);
	     B       : in  t_shared(width - 1 downto 0);
	     rand_in : in  STD_LOGIC_VECTOR(level_rand_requirement - 1 downto 0);
	     S       : out t_shared(width - 1 downto 0)
	    );
end ska_16;

architecture Behavioral of ska_16 is

	--signal rand_in : std_logic_vector(511 downto 0) :=x"11992233339933333399339933993399119922333399333333993399339933991199223333993333339933993399339911992233339933333399339933993399";	

	signal G0DD : t_shared(width - 1 downto 0);
	signal G1   : t_shared(width - 1 downto 0);
	signal G2   : t_shared(width - 1 downto 0);
	signal G3   : t_shared(width - 1 downto 0);
	signal G4   : t_shared(width - 1 downto 0);
	signal G5   : t_shared(width - 1 downto 0);
	signal G4DD : t_shared(width - 1 downto 0);

	signal P0, P0D, P0DD, P0D3, P0D4, P0D5, P0D6, P0D7, P0D8, P0D9, P0D10 : t_shared(width - 1 downto 0);
	signal P1                                                             : t_shared(width - 1 downto 0);
	signal P2                                                             : t_shared(width - 1 downto 0);
	signal P3                                                             : t_shared(width - 1 downto 0);
	signal P4                                                             : t_shared(width - 1 downto 0);
	signal P4DD                                                           : t_shared(width - 1 downto 0);
	--signal P4,P4D: std_logic_vector(7 downto 0);

	component LF_level is
		generic(width         : natural := width - 1;
		        level         : natural := 1;
		        alg           : string  := "HPC2";
		        rand_in_width : integer := level_rand_requirement);
		Port(clk     : in  STD_LOGIC;
		     G       : in  t_shared(width - 1 downto 0);
		     P       : in  t_shared(width - 1 downto 0);
		     Gdd     : out t_shared(width - 1 downto 0);
		     Pdd     : out t_shared(width - 1 downto 0);
		     rand_in : in  std_logic_vector(level_rand_requirement - 1 downto 0)
		    );
	end component;

	COMPONENT MSKxor
		Generic(d : integer := 2);
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

begin

	--level 0 generates G0 and P0 for all bits
	level0 : for I in 0 to width - 1 generate
		--G0
		G0_X : if I < width - 1 generate -- no carry out needed
			G0_X_inst : G0_shared
				port map                --(width-1)*nrnd random bits
				(clk, A(I), B(I), rand_in((I + 1) * nrnd - 1 downto I * nrnd), G0DD(I));
		end generate;
		--P0
		--P0_X: if I > 0 generate
		P0_Xinst : P0_shared
			port map(A(I), B(I), P0(I));
		--P0 registers (2)	
		PFF0_X1 : MSKreg
			generic map(d => shares)
			port map(clk, P0(I), P0D(I));
		PFF0_X2 : MSKreg
			generic map(d => shares)
			port map(clk, P0D(I), P0DD(I));
			--end generate;
	end generate level0;
	--31*nrnd random bits used

	P1 <= P0D3;
	G1 <= G0DD;

	-- save the P0 for the final sum calculation
	P0FF : for I in 0 to width - 1 generate
		PFF03d_X : MSKreg
			generic map(d => shares)
			port map(clk, P0DD(I), P0D3(I));

		PFF04d_X : MSKreg
			generic map(d => shares)
			port map(clk, P0D3(I), P0D4(I));

		PFF05d_X : MSKreg
			generic map(d => shares)
			port map(clk, P0D4(I), P0D5(I));

		PFF06d_X : MSKreg
			generic map(d => shares)
			port map(clk, P0D5(I), P0D6(I));

		PFF07d_X : MSKreg
			generic map(d => shares)
			port map(clk, P0D6(I), P0D7(I));

		PFF08d_X : MSKreg
			generic map(d => shares)
			port map(clk, P0D7(I), P0D8(I));

		PFF09d_X : MSKreg
			generic map(d => shares)
			port map(clk, P0D8(I), P0D9(I));

		PFF010d_X : MSKreg
			generic map(d => shares)
			port map(clk, P0D9(I), P0D10(I));
	end generate P0FF;

	--level 1 generates G2 and P2 for all bits
	level1 : LF_level
		generic map(width, 1)
		port map(clk, G1, P1, G2, P2, rand_in);

	--	 LF_level_1_inst : entity work.LF_level
	--	 	generic map(
	--	 		width => width,
	--	 		level => 1,
	--	 		alg   => "HPC2"
	--	 	)
	--	 	port map(
	--	 		clk     => clk,
	--	 		G       => G2,
	--	 		P       => P2,
	--	 		Gdd     => G3,
	--	 		Pdd     => P3,
	--	 		rand_in => rand_in
	--	 	);

	--level 2 generates G2 and P2 for all bits
	level2 : LF_level
		generic map(width, 2)
		port map(clk, G2, P2, G3, P3, rand_in);

	--level 3 generates G3 and P3 for all bits
	level3 : LF_level
		generic map(width, 3)
		port map(clk, G3, P3, G4, P4, rand_in);

	--level 4 generates G4 and P4 for all bits
	level4 : LF_level
		generic map(width, 4)
		port map(clk, G4, P4, G4DD, P4DD, rand_in);

	--post		
	post : for I in 1 to width - 1 generate
		S_XOR : MSKxor
			generic map(d => shares)
			port map(P0D10(I), G4DD(I - 1), S(I));
			--S(I)<= P0D4(I) xor G5dd(I-1);
	end generate;

	S(0) <= P0D10(0);
end Behavioral;

