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

entity P0_shared is
    Port ( 
		     --clk : in STD_LOGIC;
			  A : in  t_shared_bit;
           B : in  t_shared_bit;
			  --rand: in t_rand;
           G : out  t_shared_bit);
end P0_shared;



architecture unmasked of P0_shared is


begin
G(0 downto 0)<= A(0 downto 0) xor B(0 downto 0);
end unmasked;


architecture masked of P0_shared is

COMPONENT MSKxor
	generic (d: integer:=2);
	PORT(
		ina : IN t_shared_bit;
		inb : IN t_shared_bit;          
		out_c : OUT t_shared_bit
		);
	END COMPONENT;

begin
--G<= A and B;


Inst_MSKxor: MSKxor generic map (d => shares)
	PORT MAP(
		ina => a,
		inb => b,
		out_c => G
	);

end masked;

