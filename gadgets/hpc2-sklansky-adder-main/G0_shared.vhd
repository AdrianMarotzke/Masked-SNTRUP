----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:38:17 05/19/2021 
-- Design Name: 
-- Module Name:    G0_shared - Behavioral 
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
use work.constants.all;
use work.data_type.all;
--use work.interfaces_32_ska.all;

entity G0_shared is
    Port ( 
		     clk : in STD_LOGIC;
			  A : in  t_shared_bit;
           B : in  t_shared_bit;
			  rand: in t_rand;
           G : out  t_shared_bit);
end G0_shared;



architecture unmasked of G0_shared is

begin
G(0 downto 0)<= A(0 downto 0) and B(0 downto 0);

end unmasked;


---------------

architecture masked of G0_shared is

COMPONENT MSKand_HPC2
   Generic (d: integer :=2);
	PORT(
		ina : IN t_shared_bit;
		inb : IN t_shared_bit;
		rnd : IN t_rand;
		clk : IN std_logic;          
		out_c : OUT t_shared_bit
		);
	END COMPONENT;

	COMPONENT MSKreg
   Generic (d: integer :=2);
	PORT(
		clk : IN std_logic;
		in_a : IN t_shared_bit;         
		out_a : OUT t_shared_bit
		);
	END COMPONENT;
	
	signal aD : t_shared_bit;

begin
--G<= A and B;

aFF: MSKreg generic map (d=> shares)
port map
	(clk, a, aD);

Inst_MSKand_HPC2: MSKand_HPC2 
generic map (d => shares)
PORT MAP(
		ina => aD,
		inb => b,
		rnd => rand,
		clk => clk,
		out_c => G 
	);

end masked;



-----------------------------------
