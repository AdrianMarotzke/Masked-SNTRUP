library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;
use work.interfaces_32_ska.all;

entity cipher_comparison_msk is
	port(
		clock            : in  std_logic;
		reset            : in  std_logic;
		rand_in          :     std_logic_vector((q_num_bits + 1) * and_pini_nrnd - 1 downto 0);
		start_comparison : in  std_logic;
		cipher_in_valid  : in  std_logic;
		cipher_in_a      : in  t_shared(q_num_bits - 1 downto 0);
		cipher_in_b      : in  std_logic_vector(q_num_bits - 1 downto 0);
		cipher_ack       : out std_logic;
		diff_mask_valid  : out std_logic;
		diff_mask        : out t_shared(7 downto 0) -- Diff mask is all zero if difference is detected, and 00000001 when no difference. 
		                                            -- This can be fed directly to SHA as the first byte
	);
end entity cipher_comparison_msk;

architecture RTL of cipher_comparison_msk is
	type state_type is (IDLE, WAIT_INPUT_VALID, COMPUTE_OR, COMPUTE_OR_2, COMPUTE_OR_3, CHECK_DIFFERENCE, CHECK_DIFFERENCE_2, CHECK_DIFFERENCE_3, CHECK_DIFFERENCE_4, OUTPUT_DIFF_MASK);
	signal state_compare : state_type;

	signal differentbits : t_shared(q_num_bits - 1 downto 0);

	signal counter : integer range 0 to p + 64;

	signal diff_bit     : t_shared(0 downto 0);
	signal diff_bit_inv : t_shared(0 downto 0);

	component MSKxor
		generic(
			d     : integer;
			count : integer
		);
		port(
			ina   : in  std_logic_vector;
			inb   : in  std_logic_vector;
			out_c : out std_logic_vector
		);
	end component MSKxor;

	component MSKor_HPC2
		generic(d : integer);
		port(
			ina   : in  std_logic_vector;
			inb   : in  std_logic_vector;
			rnd   : in  std_logic_vector;
			clk   : in  std_logic;
			out_c : out std_logic_vector
		);
	end component MSKor_HPC2;

	component MSKinv
		generic(
			d     : integer;
			count : integer
		);
		port(
			in_a  : in  std_logic_vector;
			out_a : out std_logic_vector
		);
	end component MSKinv;
	signal xor_in_a : std_logic_vector(q_num_bits * shares - 1 downto 0);
	signal xor_in_b : std_logic_vector(q_num_bits * shares - 1 downto 0);
	signal xor_out  : std_logic_vector(q_num_bits * shares - 1 downto 0);

	signal or_in_a : std_logic_vector(q_num_bits * shares - 1 downto 0);
	signal or_in_b : std_logic_vector(q_num_bits * shares - 1 downto 0);
	signal rnd_or  : std_logic_vector(q_num_bits * and_pini_nrnd - 1 downto 0);
	signal or_out  : std_logic_vector(q_num_bits * shares - 1 downto 0);

	signal or_final_in_a : std_logic_vector(shares - 1 downto 0);
	signal or_final_in_b : std_logic_vector(shares - 1 downto 0);
	signal rnd_or_final  : std_logic_vector(and_pini_nrnd - 1 downto 0);
	signal or_final_out  : std_logic_vector(shares - 1 downto 0);
begin
	fsm_process : process(clock, reset) is
	begin
		if reset = '1' then
			state_compare   <= IDLE;
			cipher_ack      <= '0';
			diff_mask_valid <= '0';
		elsif rising_edge(clock) then
			case state_compare is
				when IDLE =>
					if start_comparison = '1' then
						state_compare <= WAIT_INPUT_VALID;
					end if;

					differentbits   <= (others => (others => '0'));
					diff_bit        <= (others => (others => '0'));
					counter         <= 0;
					diff_mask_valid <= '0';
				when WAIT_INPUT_VALID =>
					if cipher_in_valid = '1' then
						state_compare <= COMPUTE_OR;
						or_in_a       <= xor_out;
						or_in_b       <= t_shared_flatten(differentbits, q_num_bits);
						counter       <= counter + 1;
					end if;

					cipher_ack <= '0';
				when COMPUTE_OR =>
					state_compare <= COMPUTE_OR_2;
				when COMPUTE_OR_2 =>
					state_compare <= COMPUTE_OR_3;
				when COMPUTE_OR_3 =>
					cipher_ack    <= '1';
					differentbits <= t_shared_pack(or_out, q_num_bits);

					if counter /= p + 32 then
						state_compare <= WAIT_INPUT_VALID;
					else
						state_compare <= CHECK_DIFFERENCE;
						counter       <= 0;
					end if;
				when CHECK_DIFFERENCE =>
					state_compare <= CHECK_DIFFERENCE_2;
					cipher_ack    <= '0';
					or_final_in_a <= differentbits(counter);
					or_final_in_b <= diff_bit(0);
				when CHECK_DIFFERENCE_2 =>
					state_compare <= CHECK_DIFFERENCE_3;
				when CHECK_DIFFERENCE_3 =>
					state_compare <= CHECK_DIFFERENCE_4;
				when CHECK_DIFFERENCE_4 =>
					diff_bit(0) <= or_final_out;
					counter     <= counter + 1;

					if counter = q_num_bits - 1 then
						state_compare <= OUTPUT_DIFF_MASK;
					else
						state_compare <= CHECK_DIFFERENCE;
					end if;

				when OUTPUT_DIFF_MASK =>
					state_compare   <= IDLE;
					diff_mask       <= (others => (others => '0'));
					diff_mask(0)    <= diff_bit_inv(0);
					diff_mask_valid <= '1';
			end case;
		end if;
	end process fsm_process;

	xor_in_a <= t_shared_flatten(cipher_in_a, q_num_bits) when cipher_in_valid = '1' else (others => '0');

	rnd_or       <= rand_in(q_num_bits * and_pini_nrnd - 1 downto 0);
	rnd_or_final <= rand_in((q_num_bits + 1) * and_pini_nrnd - 1 downto q_num_bits * and_pini_nrnd);

	dummy_mask_cipher_b : process(cipher_in_b, cipher_in_valid) is
	begin
		xor_in_b <= (others => '0');
		if cipher_in_valid = '1' then
			for i in 0 to q_num_bits - 1 loop
				xor_in_b(i * shares) <= cipher_in_b(i);
			end loop;
		else
			xor_in_b <= (others => '0');
		end if;
	end process dummy_mask_cipher_b;

	MSKxor_inst : component MSKxor
		generic map(
			d     => shares,
			count => q_num_bits
		)
		port map(
			ina   => xor_in_a,
			inb   => xor_in_b,
			out_c => xor_out
		);

	gen_mask_or : for i in 0 to q_num_bits - 1 generate
		MSKor_HPC2_inst : component MSKor_HPC2
			generic map(
				d => shares
			)
			port map(
				ina   => or_in_a((i + 1) * shares - 1 downto i * shares),
				inb   => or_in_b((i + 1) * shares - 1 downto i * shares),
				rnd   => rnd_or((i + 1) * and_pini_nrnd - 1 downto i * and_pini_nrnd),
				clk   => clock,
				out_c => or_out((i + 1) * shares - 1 downto i * shares)
			);
	end generate gen_mask_or;

	MSKor_HPC2_final : component MSKor_HPC2
		generic map(
			d => shares
		)
		port map(
			ina   => or_final_in_a,
			inb   => or_final_in_b,
			rnd   => rnd_or_final,
			clk   => clock,
			out_c => or_final_out
		);

	MSKinv_inst : component MSKinv
		generic map(
			d     => shares,
			count => 1
		)
		port map(
			in_a  => diff_bit(0),
			out_a => diff_bit_inv(0)
		);

end architecture RTL;
