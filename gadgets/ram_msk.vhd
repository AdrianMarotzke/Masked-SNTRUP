library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;

entity ram_msk is
	Generic(
		ADDRESS_WIDTH : integer := 8;
		DATA_WIDTH    : integer := 8
	);
	port(
		clock      : in  std_logic;
		address_a  : in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
		write_a    : in  std_logic;
		data_in_a  : in  t_shared(DATA_WIDTH - 1 downto 0);
		data_out_a : out t_shared(DATA_WIDTH - 1 downto 0);
		address_b  : in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
		write_b    : in  std_logic;
		data_in_b  : in  t_shared(DATA_WIDTH - 1 downto 0);
		data_out_b : out t_shared(DATA_WIDTH - 1 downto 0)
	);
end entity ram_msk;

architecture RTL of ram_msk is
--	type t_shared_trans is array (shares - 1 downto 0) of std_logic_vector(DATA_WIDTH - 1 downto 0);
--
--	function t_shared_trans_to_t_shared(shared_in_trans : in t_shared_trans) return t_shared is
--		variable t_shared_out : t_shared(DATA_WIDTH - 1 downto 0);
--	begin
--		for I in 0 to DATA_WIDTH - 1 loop
--			for J in 0 to shares - 1 loop
--				t_shared_out(I)(J) := shared_in_trans(J)(I);
--			end loop;
--		end loop;
--		return (t_shared_out);
--	end t_shared_trans_to_t_shared;
--
--	function t_shared_to_t_shared_trans(shared_in : in t_shared) return t_shared_trans is
--		variable t_shared_trans_out : t_shared_trans;
--	begin
--		for I in 0 to DATA_WIDTH - 1 loop
--			for J in 0 to shares - 1 loop
--				t_shared_trans_out(J)(I) := shared_in(I)(J);
--			end loop;
--		end loop;
--		return (t_shared_trans_out);
--	end t_shared_to_t_shared_trans;
--
--	signal data_in_a_trans  : t_shared_trans;
--	signal data_out_a_trans : t_shared_trans;
--
--	signal data_in_b_trans  : t_shared_trans;
--	signal data_out_b_trans : t_shared_trans;
	
	signal data_in_a_flat : STD_LOGIC_VECTOR(DATA_WIDTH * shares - 1 downto 0);
	signal data_out_a_flat : STD_LOGIC_VECTOR(DATA_WIDTH * shares - 1 downto 0);
	signal data_in_b_flat : STD_LOGIC_VECTOR(DATA_WIDTH * shares - 1 downto 0);
	signal data_out_b_flat : STD_LOGIC_VECTOR(DATA_WIDTH * shares - 1 downto 0);

begin
--	data_in_a_trans <= t_shared_to_t_shared_trans(data_in_a);
--	data_out_a      <= t_shared_trans_to_t_shared(data_out_a_trans);
--	data_in_b_trans <= t_shared_to_t_shared_trans(data_in_b);
--	data_out_b      <= t_shared_trans_to_t_shared(data_out_b_trans);
--
--	gen_ram : for i in 0 to shares - 1 generate
--		block_ram_inst : entity work.block_ram
--			generic map(
--				ADDRESS_WIDTH => ADDRESS_WIDTH,
--				DATA_WIDTH    => DATA_WIDTH,
--				DUAL_PORT     => TRUE
--			)
--			port map(
--				clock      => clock,
--				address_a  => address_a,
--				write_a    => write_a,
--				data_in_a  => data_in_a_trans(i),
--				data_out_a => data_out_a_trans(i),
--				address_b  => address_b,
--				write_b    => write_b,
--				data_in_b  => data_in_b_trans(i),
--				data_out_b => data_out_b_trans(i)
--			);
--	end generate gen_ram;

	data_in_a_flat <= t_shared_flatten(data_in_a, DATA_WIDTH);
	data_out_a      <= t_shared_pack(data_out_a_flat, DATA_WIDTH);
	data_in_b_flat <= t_shared_flatten(data_in_b, DATA_WIDTH);
	data_out_b      <= t_shared_pack(data_out_b_flat, DATA_WIDTH);

	block_ram_inst : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => ADDRESS_WIDTH,
			DATA_WIDTH    => DATA_WIDTH * shares,
			DUAL_PORT     => TRUE
		)
		port map(
			clock      => clock,
			address_a  => address_a,
			write_a    => write_a,
			data_in_a  => data_in_a_flat,
			data_out_a => data_out_a_flat,
			address_b  => address_b,
			write_b    => write_b,
			data_in_b  => data_in_b_flat,
			data_out_b => data_out_b_flat
		);
end architecture RTL;
