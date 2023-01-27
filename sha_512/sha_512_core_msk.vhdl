--MIT License
--
--Original work Copyright (c) 2017 Danny Savory
--Modified work Copyright (c) 2020, 2023 Adrian Marotzke
--
--Permission is hereby granted, free of charge, to any person obtaining a copy
--of this software and associated documentation files (the "Software"), to deal
--in the Software without restriction, including without limitation the rights
--to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--copies of the Software, and to permit persons to whom the Software is
--furnished to do so, subject to the following conditions:
--
--The above copyright notice and this permission notice shall be included in all
--copies or substantial portions of the Software.
--
--THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--SOFTWARE.

-- ############################################################################
--  The official specifications of the SHA-256 algorithm can be found here:
--      http://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf

-- ##################################################################
--     This SHA_512_CORE module reads in PADDED message blocks (from
--      an external source) and hashes the resulting message
-- ##################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.sha_512_pkg.all;

use work.data_type.all;
use work.constants.all;
use work.interfaces_64_ska.all;

entity sha_512_core_msk is
	generic(
		RESET_VALUE : std_logic := '0'  --reset enable value
	);
	port(
		clock              : in  std_logic;
		reset              : in  std_logic;
		data_ready         : in  std_logic; --the edge of this signal triggers the capturing of input data and hashing it.
		n_blocks           : in  natural range 0 to 16; --N, the number of (padded) message blocks
		read_msg_fifo_en   : out std_logic;
		read_msg_fifo_data : in  t_shared(WORD_SIZE - 1 downto 0);
		rand_in            : in  std_logic_vector(level_rand_requirement - 1 downto 0);
		ready              : out std_logic;
		finished           : out std_logic; -- output is sent 1 clock cycle after finished is set to '1'
		data_out           : out t_shared(WORD_SIZE - 1 downto 0) --masked SHA-512 results in a 512-bit hash value, 64 bits at a time
	);
end entity;

architecture RTL of sha_512_core_msk is
	signal HASH_ROUND_COUNTER    : natural; -- := 0;
	--signal MSG_BLOCK_COUNTER     : natural := 0;
	constant HASH_02_COUNT_LIMIT : natural := 80;

	constant adder_delay : integer := 14;

	signal HASH_02_COUNTER : natural range 0 to HASH_02_COUNT_LIMIT;

	--Working variables, 8 64-bit words
	signal a : t_shared(WORD_SIZE - 1 downto 0); -- := (others => '0');
	signal b : t_shared(WORD_SIZE - 1 downto 0); -- := (others => '0');
	signal c : t_shared(WORD_SIZE - 1 downto 0); -- := (others => '0');
	signal d : t_shared(WORD_SIZE - 1 downto 0); -- := (others => '0');
	signal e : t_shared(WORD_SIZE - 1 downto 0); -- := (others => '0');
	signal f : t_shared(WORD_SIZE - 1 downto 0); -- := (others => '0');
	signal g : t_shared(WORD_SIZE - 1 downto 0); -- := (others => '0');
	signal h : t_shared(WORD_SIZE - 1 downto 0); -- := (others => '0');

	signal a_trans : t_shared_trans;    -- := (others => '0');
	signal b_trans : t_shared_trans;    -- := (others => '0');
	signal c_trans : t_shared_trans;    -- := (others => '0');
	signal d_trans : t_shared_trans;    -- := (others => '0');
	signal e_trans : t_shared_trans;    -- := (others => '0');
	signal f_trans : t_shared_trans;    -- := (others => '0');
	signal g_trans : t_shared_trans;    -- := (others => '0');
	signal h_trans : t_shared_trans;    -- := (others => '0');

	signal w0 : t_shared_trans;         -- := (others => '0');

	--Hash values w/ initial hash values; 8 64-bit words
	constant HV_INITIAL_VALUES : H_DATA := (X"6a09e667f3bcc908", X"bb67ae8584caa73b",
	                                        X"3c6ef372fe94f82b", X"a54ff53a5f1d36f1",
	                                        X"510e527fade682d1", X"9b05688c2b3e6c1f",
	                                        X"1f83d9abfb41bd6b", X"5be0cd19137e2179");

	--sliding window registers for intermediate Message Schedule values;
	type window_type is array (0 to 16) of t_shared(WORD_SIZE - 1 downto 0);
	signal w_window : window_type;

	type SHA_512_HASH_CORE_STATE is (RESET_STATE, IDLE, READ_MSG_BLOCK, HASH_01_HV0, HASH_01_HV1, HASH_01_HV2, HASH_01_HV3, HASH_01_HV4,
	                                 HASH_01_HV5, HASH_01_HV6, HASH_01_HV7, HASH_01_END,
	                                 HASH_02_WNEW, HASH_02_WNEW_ADD_L1_6, HASH_02_WNEW_ADD_L0_15, HASH_02_WNEW_WAIT, HASH_02_WNEW_ADD_B, HASH_02_WNEW_WAIT_2,
	                                 HASH_02_CH, HASH_02_CH_a, HASH_02_CH_b, HASH_02_MA, HASH_02_MA_a, HASH_02_MA_b,
	                                 HASH_02_ADD_h_u1, HASH_02_ADD_ch_k, HASH_02_ADD_WAIT, HASH_02_ADD_RES_a, HASH_02_ADD_RES_b,
	                                 HASH_02_ADD_WAIT_2, HASH_02_ADD_w, HASH_02_ADD_u0_ma, HASH_02_ADD_WAIT_3,
	                                 HASH_02_ADD_d, HASH_02_ADD_RES2_b, HASH_02_ADD_WAIT_4,
	                                 HASH_02_WRITE_e, HASH_02_WRITE_a,
	                                 HASH_02a, HASH_02b, HASH_03a, HASH_03_HV0, HASH_03_HV1,
	                                 HASH_03_HV2, HASH_03_HV3, HASH_03_HV4, HASH_03_HV5, HASH_03_HV6, HASH_03_HV7, HASH_03_WAIT,
	                                 HASH_03_WRITE_HV0, HASH_03_WRITE_HV1, HASH_03_WRITE_HV2, HASH_03_WRITE_HV3, HASH_03_WRITE_HV4, HASH_03_WRITE_HV5, HASH_03_WRITE_HV6, HASH_03_WRITE_HV7,
	                                 HASH_03_DONE, DONE_a --, DONE_b, DONE_c, DONE_d
	                                );
	signal CURRENT_STATE, NEXT_STATE : SHA_512_HASH_CORE_STATE;
	--signal PREVIOUS_STATE            : SHA_512_HASH_CORE_STATE := READ_MSG_BLOCK;

	signal k_ROM_data_out : STD_LOGIC_VECTOR(WORD_SIZE - 1 downto 0);

	signal HV_ram_address_a  : STD_LOGIC_VECTOR(3 - 1 downto 0);
	signal HV_ram_data_out_a : t_shared(WORD_SIZE - 1 downto 0);
	signal HV_ram_address_b  : STD_LOGIC_VECTOR(3 - 1 downto 0);
	signal HV_ram_write_b    : STD_LOGIC;
	signal HV_ram_data_in_b  : t_shared(WORD_SIZE - 1 downto 0);

	signal n_blocks_reg : natural range 0 to 16;

	signal adder_in_a    : t_shared(width - 1 downto 0);
	signal adder_in_b    : t_shared(width - 1 downto 0);
	signal adder_rand_in : STD_LOGIC_VECTOR(level_rand_requirement - 1 downto 0);
	signal adder_out     : t_shared(width - 1 downto 0);

	signal L0_input  : std_logic_vector(WORD_SIZE * shares - 1 downto 0);
	signal L0_output : std_logic_vector(WORD_SIZE * shares - 1 downto 0);

	signal L1_input  : std_logic_vector(WORD_SIZE * shares - 1 downto 0);
	signal L1_output : std_logic_vector(WORD_SIZE * shares - 1 downto 0);

	signal u0_input  : std_logic_vector(WORD_SIZE * shares - 1 downto 0);
	signal u0_output : std_logic_vector(WORD_SIZE * shares - 1 downto 0);

	signal u1_input  : std_logic_vector(WORD_SIZE * shares - 1 downto 0);
	signal u1_output : std_logic_vector(WORD_SIZE * shares - 1 downto 0);

	signal ch_e_input : std_logic_vector(WORD_SIZE * shares - 1 downto 0);
	signal ch_f_input : std_logic_vector(WORD_SIZE * shares - 1 downto 0);
	signal ch_g_input : std_logic_vector(WORD_SIZE * shares - 1 downto 0);
	signal ch_rand_in : std_logic_vector(and_pini_nrnd * WORD_SIZE - 1 downto 0);
	signal ch_output  : std_logic_vector(WORD_SIZE * shares - 1 downto 0);

	signal ma_a_input : std_logic_vector(WORD_SIZE * shares - 1 downto 0);
	signal ma_b_input : std_logic_vector(WORD_SIZE * shares - 1 downto 0);
	signal ma_c_input : std_logic_vector(WORD_SIZE * shares - 1 downto 0);
	signal ma_rand_in : std_logic_vector(and_pini_nrnd * WORD_SIZE * 2 - 1 downto 0);
	signal ma_output  : std_logic_vector(WORD_SIZE * shares - 1 downto 0);

	signal counter : integer range 0 to adder_delay + 2;

	signal finished_reg : std_logic;

begin

	--current state logic
	process(clock, reset)
	begin
		if (reset = RESET_VALUE) then
			CURRENT_STATE <= RESET_STATE;
		elsif rising_edge(clock) then
			CURRENT_STATE <= NEXT_STATE;
		end if;
	end process;

	--next state logic
	process(CURRENT_STATE, HASH_ROUND_COUNTER, HASH_02_COUNTER, reset, data_ready, n_blocks_reg, counter)
	begin
		case CURRENT_STATE is
			when RESET_STATE =>
				if (reset = RESET_VALUE) then
					NEXT_STATE <= RESET_STATE;
				else
					NEXT_STATE <= IDLE;
				end if;
			when IDLE =>
				if (data_ready = '1') then
					NEXT_STATE <= READ_MSG_BLOCK;
				else
					NEXT_STATE <= IDLE;
				end if;
			when READ_MSG_BLOCK =>
				NEXT_STATE <= HASH_01_HV0;
			when HASH_01_HV0 =>
				NEXT_STATE <= HASH_01_HV1;
			when HASH_01_HV1 =>
				NEXT_STATE <= HASH_01_HV2;
			when HASH_01_HV2 =>
				NEXT_STATE <= HASH_01_HV3;
			when HASH_01_HV3 =>
				NEXT_STATE <= HASH_01_HV4;
			when HASH_01_HV4 =>
				NEXT_STATE <= HASH_01_HV5;
			when HASH_01_HV5 =>
				NEXT_STATE <= HASH_01_HV6;
			when HASH_01_HV6 =>
				NEXT_STATE <= HASH_01_HV7;
			when HASH_01_HV7 =>
				NEXT_STATE <= HASH_01_END;
			when HASH_01_END =>
				NEXT_STATE <= HASH_02_WNEW;
			when HASH_02_WNEW =>
				if HASH_02_COUNTER < 16 then
					NEXT_STATE <= HASH_02_CH;
				else
					NEXT_STATE <= HASH_02_WNEW_ADD_L1_6;
				end if;
			when HASH_02_WNEW_ADD_L1_6 =>
				NEXT_STATE <= HASH_02_WNEW_ADD_L0_15;
			when HASH_02_WNEW_ADD_L0_15 =>
				NEXT_STATE <= HASH_02_WNEW_WAIT;
			when HASH_02_WNEW_WAIT =>
				if counter = adder_delay - 1 then
					NEXT_STATE <= HASH_02_WNEW_ADD_B;
				end if;
			when HASH_02_WNEW_ADD_B =>
				NEXT_STATE <= HASH_02_WNEW_WAIT_2;
			when HASH_02_WNEW_WAIT_2 =>
				if counter = adder_delay then -- wait one more clock cycle
					NEXT_STATE <= HASH_02_CH;
				end if;
			when HASH_02_CH =>
				NEXT_STATE <= HASH_02_CH_a;
			when HASH_02_CH_a =>
				NEXT_STATE <= HASH_02_CH_b;
			when HASH_02_CH_b =>
				NEXT_STATE <= HASH_02_MA;
			when HASH_02_MA =>
				NEXT_STATE <= HASH_02_MA_a;
			when HASH_02_MA_a =>
				NEXT_STATE <= HASH_02_MA_b;
			when HASH_02_MA_b =>
				NEXT_STATE <= HASH_02_ADD_h_u1;
			when HASH_02_ADD_h_u1 =>
				NEXT_STATE <= HASH_02_ADD_ch_k;
			when HASH_02_ADD_ch_k =>
				NEXT_STATE <= HASH_02_ADD_WAIT;
			when HASH_02_ADD_WAIT =>
				if counter = adder_delay - 2 then -- 1 clock cycle under the adder delay, ass we started 2 additions
					NEXT_STATE <= HASH_02_ADD_RES_a;
				end if;
			when HASH_02_ADD_RES_a =>
				NEXT_STATE <= HASH_02_ADD_RES_b;
			when HASH_02_ADD_RES_b =>
				NEXT_STATE <= HASH_02_ADD_WAIT_2;
			when HASH_02_ADD_WAIT_2 =>
				if counter = adder_delay - 1 then
					NEXT_STATE <= HASH_02_ADD_w;
				end if;
			when HASH_02_ADD_w =>
				NEXT_STATE <= HASH_02_ADD_u0_ma;
			when HASH_02_ADD_u0_ma =>
				NEXT_STATE <= HASH_02_ADD_WAIT_3;
			when HASH_02_ADD_WAIT_3 =>
				if counter = adder_delay - 2 then -- 1 clock cycle under the adder delay
					NEXT_STATE <= HASH_02_ADD_d;
				end if;
			when HASH_02_ADD_d =>
				NEXT_STATE <= HASH_02_ADD_RES2_b;
			when HASH_02_ADD_RES2_b =>
				NEXT_STATE <= HASH_02_ADD_WAIT_4;
			when HASH_02_ADD_WAIT_4 =>
				if counter = adder_delay - 2 then -- 1 clock cycle under the adder delay, as we started 2 additions
					NEXT_STATE <= HASH_02_WRITE_e;
				end if;
			when HASH_02_WRITE_e =>
				NEXT_STATE <= HASH_02_WRITE_a;
			when HASH_02_WRITE_a =>
				NEXT_STATE <= HASH_02a;
			when HASH_02a =>
				NEXT_STATE <= HASH_02b;
			when HASH_02b =>
				if (HASH_02_COUNTER = HASH_02_COUNT_LIMIT) then
					NEXT_STATE <= HASH_03a;
				else
					NEXT_STATE <= HASH_02_WNEW;
				end if;
			when HASH_03a =>
				NEXT_STATE <= HASH_03_HV0;
			when HASH_03_HV0 =>
				NEXT_STATE <= HASH_03_HV1;
			when HASH_03_HV1 =>
				NEXT_STATE <= HASH_03_HV2;
			when HASH_03_HV2 =>
				NEXT_STATE <= HASH_03_HV3;
			when HASH_03_HV3 =>
				NEXT_STATE <= HASH_03_HV4;
			when HASH_03_HV4 =>
				NEXT_STATE <= HASH_03_HV5;
			when HASH_03_HV5 =>
				NEXT_STATE <= HASH_03_HV6;
			when HASH_03_HV6 =>
				NEXT_STATE <= HASH_03_HV7;
			when HASH_03_HV7 =>
				NEXT_STATE <= HASH_03_WAIT;
			when HASH_03_WAIT =>
				if counter = adder_delay - 8 then
					NEXT_STATE <= HASH_03_WRITE_HV0;
				end if;
			when HASH_03_WRITE_HV0 =>
				NEXT_STATE <= HASH_03_WRITE_HV1;
			when HASH_03_WRITE_HV1 =>
				NEXT_STATE <= HASH_03_WRITE_HV2;
			when HASH_03_WRITE_HV2 =>
				NEXT_STATE <= HASH_03_WRITE_HV3;
			when HASH_03_WRITE_HV3 =>
				NEXT_STATE <= HASH_03_WRITE_HV4;
			when HASH_03_WRITE_HV4 =>
				NEXT_STATE <= HASH_03_WRITE_HV5;
			when HASH_03_WRITE_HV5 =>
				NEXT_STATE <= HASH_03_WRITE_HV6;
			when HASH_03_WRITE_HV6 =>
				NEXT_STATE <= HASH_03_WRITE_HV7;
			when HASH_03_WRITE_HV7 =>
				NEXT_STATE <= HASH_03_DONE;
			when HASH_03_DONE =>
				if (HASH_ROUND_COUNTER = n_blocks_reg - 1) then
					NEXT_STATE <= DONE_a;
				else
					NEXT_STATE <= IDLE;
				end if;
			when DONE_a =>
				NEXT_STATE <= IDLE;

		end case;
	end process;

	--hash logic
	process(clock, reset)
		variable w_new : t_shared(WORD_SIZE - 1 downto 0);

		variable temp_trans : t_shared_trans := (others => (others => '0'));

	begin
		if (reset = RESET_VALUE) then
			ready   <= '0';
			counter <= 0;
		elsif (clock'event and clock = '1') then
			a <= a;
			b <= b;
			c <= c;
			d <= d;
			e <= e;
			f <= f;
			g <= g;
			h <= h;

			HASH_02_COUNTER    <= HASH_02_COUNTER;
			HASH_ROUND_COUNTER <= HASH_ROUND_COUNTER;
			HV_ram_write_b     <= '0';
			case CURRENT_STATE is
				when RESET_STATE =>

				when IDLE =>            --the IDLE stage is a stall stage, perhaps waiting for new message block to arrive.
					ready            <= '1';
					read_msg_fifo_en <= '0';
					HASH_02_COUNTER  <= 0;
				when READ_MSG_BLOCK =>
					ready            <= '0';
					n_blocks_reg     <= n_blocks;
					HV_ram_address_a <= "000";
				when HASH_01_HV0 =>
					HV_ram_address_a <= "001";
				when HASH_01_HV1 =>
					HV_ram_address_a <= "010";
					if (HASH_ROUND_COUNTER = 0) then
						temp_trans(0)    := HV_INITIAL_VALUES(0);
						a                <= t_shared_trans_to_t_shared(temp_trans);
						HV_ram_address_b <= "000";
						HV_ram_write_b   <= '1';
						HV_ram_data_in_b <= t_shared_trans_to_t_shared(temp_trans);
					else
						a <= HV_ram_data_out_a;
					end if;
				when HASH_01_HV2 =>
					HV_ram_address_a <= "011";
					if (HASH_ROUND_COUNTER = 0) then
						temp_trans(0)    := HV_INITIAL_VALUES(1);
						b                <= t_shared_trans_to_t_shared(temp_trans);
						HV_ram_address_b <= "001";
						HV_ram_write_b   <= '1';
						HV_ram_data_in_b <= t_shared_trans_to_t_shared(temp_trans);
					else
						b <= HV_ram_data_out_a;
					end if;
				when HASH_01_HV3 =>
					HV_ram_address_a <= "100";
					if (HASH_ROUND_COUNTER = 0) then
						temp_trans(0)    := HV_INITIAL_VALUES(2);
						c                <= t_shared_trans_to_t_shared(temp_trans);
						HV_ram_address_b <= "010";
						HV_ram_write_b   <= '1';
						HV_ram_data_in_b <= t_shared_trans_to_t_shared(temp_trans);
					else
						c <= HV_ram_data_out_a;
					end if;
				when HASH_01_HV4 =>
					HV_ram_address_a <= "101";
					if (HASH_ROUND_COUNTER = 0) then
						temp_trans(0)    := HV_INITIAL_VALUES(3);
						d                <= t_shared_trans_to_t_shared(temp_trans);
						HV_ram_address_b <= "011";
						HV_ram_write_b   <= '1';
						HV_ram_data_in_b <= t_shared_trans_to_t_shared(temp_trans);
					else
						d <= HV_ram_data_out_a;
					end if;
				when HASH_01_HV5 =>
					HV_ram_address_a <= "110";
					if (HASH_ROUND_COUNTER = 0) then
						temp_trans(0)    := HV_INITIAL_VALUES(4);
						e                <= t_shared_trans_to_t_shared(temp_trans);
						HV_ram_address_b <= "100";
						HV_ram_write_b   <= '1';
						HV_ram_data_in_b <= t_shared_trans_to_t_shared(temp_trans);
					else
						e <= HV_ram_data_out_a;
					end if;
				when HASH_01_HV6 =>
					HV_ram_address_a <= "111";
					if (HASH_ROUND_COUNTER = 0) then
						temp_trans(0)    := HV_INITIAL_VALUES(5);
						f                <= t_shared_trans_to_t_shared(temp_trans);
						HV_ram_address_b <= "101";
						HV_ram_write_b   <= '1';
						HV_ram_data_in_b <= t_shared_trans_to_t_shared(temp_trans);
					else
						f <= HV_ram_data_out_a;
					end if;
				when HASH_01_HV7 =>
					if (HASH_ROUND_COUNTER = 0) then
						temp_trans(0)    := HV_INITIAL_VALUES(6);
						g                <= t_shared_trans_to_t_shared(temp_trans);
						HV_ram_address_b <= "110";
						HV_ram_write_b   <= '1';
						HV_ram_data_in_b <= t_shared_trans_to_t_shared(temp_trans);
					else
						g <= HV_ram_data_out_a;
					end if;
				when HASH_01_END =>
					if (HASH_ROUND_COUNTER = 0) then
						temp_trans(0)    := HV_INITIAL_VALUES(7);
						h                <= t_shared_trans_to_t_shared(temp_trans);
						HV_ram_address_b <= "111";
						HV_ram_write_b   <= '1';
						HV_ram_data_in_b <= t_shared_trans_to_t_shared(temp_trans);
					else
						h <= HV_ram_data_out_a;
					end if;
					read_msg_fifo_en <= '1';
				when HASH_02_WNEW =>
					read_msg_fifo_en <= '0';
					if HASH_02_COUNTER < 16 then
						w_new := read_msg_fifo_data;

						w_window(0) <= w_new;

						for i in 1 to 16 loop
							w_window(i) <= w_window(i - 1);
						end loop;
					else

						--w_new    := std_logic_vector(unsigned(SIGMA_LCASE_1(w_window(1))) + unsigned(w_window(6)) + unsigned(SIGMA_LCASE_0(w_window(14))) + unsigned(w_window(15)));
					end if;
				when HASH_02_WNEW_ADD_L1_6 =>
					adder_in_a <= t_shared_pack(L1_output, WORD_SIZE);
					adder_in_b <= w_window(6);
				when HASH_02_WNEW_ADD_L0_15 =>
					adder_in_a <= t_shared_pack(L0_output, WORD_SIZE);
					adder_in_b <= w_window(15);
				when HASH_02_WNEW_WAIT =>

					counter <= counter + 1;
					if counter = adder_delay - 1 then
						adder_in_a <= adder_out;
						counter    <= 0;
					end if;

				when HASH_02_WNEW_ADD_B =>
					counter    <= 0;
					adder_in_b <= adder_out;
				when HASH_02_WNEW_WAIT_2 =>
					counter <= counter + 1;
					if counter = adder_delay then
						w_new   := adder_out;
						counter <= 0;

						w_window(0) <= w_new;

						for i in 1 to 16 loop
							w_window(i) <= w_window(i - 1);
						end loop;
					end if;

				when HASH_02_CH =>
					counter    <= 0;
					ch_e_input <= t_shared_flatten(e, WORD_SIZE);
					ch_f_input <= t_shared_flatten(f, WORD_SIZE);
					ch_g_input <= t_shared_flatten(g, WORD_SIZE);

					if (HASH_02_COUNTER = HASH_02_COUNT_LIMIT) then
						HASH_02_COUNTER <= 0;
					end if;

				when HASH_02_CH_a =>

				when HASH_02_CH_b =>

				when HASH_02_MA =>
					ma_a_input <= t_shared_flatten(a, WORD_SIZE);
					ma_b_input <= t_shared_flatten(b, WORD_SIZE);
					ma_c_input <= t_shared_flatten(c, WORD_SIZE);
				when HASH_02_MA_a =>
				when HASH_02_MA_b =>

				when HASH_02_ADD_h_u1 =>
					adder_in_a <= t_shared_pack(u1_output, WORD_SIZE);
					adder_in_b <= h;
				when HASH_02_ADD_ch_k =>
					adder_in_a    <= t_shared_pack(ch_output, WORD_SIZE);
					temp_trans(0) := k_ROM_data_out;
					adder_in_b    <= t_shared_trans_to_t_shared(temp_trans);
				when HASH_02_ADD_WAIT =>
					counter <= counter + 1;
				when HASH_02_ADD_RES_a =>
					counter    <= 0;
					adder_in_a <= adder_out;
				when HASH_02_ADD_RES_b =>
					adder_in_b <= adder_out;
				when HASH_02_ADD_WAIT_2 =>
					counter <= counter + 1;
				when HASH_02_ADD_w =>
					adder_in_a <= adder_out;
					adder_in_b <= w_window(0);
				when HASH_02_ADD_u0_ma =>
					adder_in_a <= t_shared_pack(ma_output, WORD_SIZE);
					adder_in_b <= t_shared_pack(u0_output, WORD_SIZE);
					counter    <= 0;
				when HASH_02_ADD_WAIT_3 =>
					counter <= counter + 1;
				when HASH_02_ADD_d =>
					adder_in_a <= adder_out;
					adder_in_b <= d;
				when HASH_02_ADD_RES2_b =>
					adder_in_b <= adder_out;
					counter    <= 0;
				when HASH_02_ADD_WAIT_4 =>
					counter <= counter + 1;
				when HASH_02_WRITE_e =>
					e <= adder_out;
					f <= e;
					g <= f;
					h <= g;
				when HASH_02_WRITE_a =>
					a <= adder_out;
					b <= a;
					c <= b;
					d <= c;
				when HASH_02a =>
					read_msg_fifo_en <= '0';
					HASH_02_COUNTER  <= HASH_02_COUNTER + 1;
					counter          <= 0;
				when HASH_02b =>
					read_msg_fifo_en <= '1';
					if HASH_02_COUNTER >= 16 then
						read_msg_fifo_en <= '0';
					end if;
					HV_ram_address_a <= "000";

				when HASH_03a =>
					HV_ram_address_a <= "001";
				when HASH_03_HV0 =>
					HV_ram_address_a <= "010";
					adder_in_a       <= HV_ram_data_out_a;
					adder_in_b       <= a;

				--					HV_ram_address_b <= "000";
				--					HV_ram_write_b   <= '1';
				--					HV_ram_data_in_b <= HV_addition_output;
				when HASH_03_HV1 =>
					HV_ram_address_a <= "011";
					adder_in_a       <= HV_ram_data_out_a;
					adder_in_b       <= b;

				--					HV_ram_address_b <= "001";
				--					HV_ram_write_b   <= '1';
				--					HV_ram_data_in_b <= HV_addition_output;
				when HASH_03_HV2 =>
					HV_ram_address_a <= "100";
					adder_in_a       <= HV_ram_data_out_a;
					adder_in_b       <= c;

				--					HV_ram_address_b <= "010";
				--					HV_ram_write_b   <= '1';
				--					HV_ram_data_in_b <= HV_addition_output;
				when HASH_03_HV3 =>
					HV_ram_address_a <= "101";
					adder_in_a       <= HV_ram_data_out_a;
					adder_in_b       <= d;

				--					HV_ram_address_b <= "011";
				--					HV_ram_write_b   <= '1';
				--					HV_ram_data_in_b <= HV_addition_output;
				when HASH_03_HV4 =>
					HV_ram_address_a <= "110";
					adder_in_a       <= HV_ram_data_out_a;
					adder_in_b       <= e;

				--					HV_ram_address_b <= "100";
				--					HV_ram_write_b   <= '1';
				--					HV_ram_data_in_b <= HV_addition_output;
				when HASH_03_HV5 =>
					HV_ram_address_a <= "111";
					adder_in_a       <= HV_ram_data_out_a;
					adder_in_b       <= f;
					counter          <= 0;
				--					HV_ram_address_b <= "101";
				--					HV_ram_write_b   <= '1';
				--					HV_ram_data_in_b <= HV_addition_output;
				when HASH_03_HV6 =>
					adder_in_a <= HV_ram_data_out_a;
					adder_in_b <= g;
				when HASH_03_HV7 =>
					adder_in_a <= HV_ram_data_out_a;
					adder_in_b <= h;

				--					HV_ram_address_b <= "110";
				--					HV_ram_write_b   <= '1';
				--					HV_ram_data_in_b <= HV_addition_output;
				when HASH_03_WAIT =>
					counter <= counter + 1;
				when HASH_03_WRITE_HV0 =>
					HV_ram_address_b <= "000";
					HV_ram_write_b   <= '1';
					HV_ram_data_in_b <= adder_out;
				when HASH_03_WRITE_HV1 =>
					HV_ram_address_b <= "001";
					HV_ram_write_b   <= '1';
					HV_ram_data_in_b <= adder_out;
				when HASH_03_WRITE_HV2 =>
					HV_ram_address_b <= "010";
					HV_ram_write_b   <= '1';
					HV_ram_data_in_b <= adder_out;
				when HASH_03_WRITE_HV3 =>
					HV_ram_address_b <= "011";
					HV_ram_write_b   <= '1';
					HV_ram_data_in_b <= adder_out;
				when HASH_03_WRITE_HV4 =>
					HV_ram_address_b <= "100";
					HV_ram_write_b   <= '1';
					HV_ram_data_in_b <= adder_out;
				when HASH_03_WRITE_HV5 =>
					HV_ram_address_b <= "101";
					HV_ram_write_b   <= '1';
					HV_ram_data_in_b <= adder_out;
				when HASH_03_WRITE_HV6 =>
					HV_ram_address_b <= "110";
					HV_ram_write_b   <= '1';
					HV_ram_data_in_b <= adder_out;
				when HASH_03_WRITE_HV7 =>
					HV_ram_address_b <= "111";
					HV_ram_write_b   <= '1';
					HV_ram_data_in_b <= adder_out;
				when HASH_03_DONE =>
					counter            <= 0;
					HASH_ROUND_COUNTER <= HASH_ROUND_COUNTER + 1; --increment counter, read in next message block
				when DONE_a =>
					HASH_ROUND_COUNTER <= 0;
			end case;
		end if;
	end process;

	K_ROM_inst : entity work.K_ROM
		port map(
			clock    => clock,
			address  => HASH_02_COUNTER,
			data_out => k_ROM_data_out
		);

	HV_SDP_dist_RAM_inst : entity work.ram_msk
		generic map(
			ADDRESS_WIDTH => 3,
			DATA_WIDTH    => 64
		)
		port map(
			clock      => clock,
			address_a  => HV_ram_address_a,
			write_a    => '0',
			data_in_a  => (others => (others => '0')),
			data_out_a => HV_ram_data_out_a,
			address_b  => HV_ram_address_b,
			write_b    => HV_ram_write_b,
			data_in_b  => HV_ram_data_in_b,
			data_out_b => open
		);

	ska_64_inst : entity work.ska_64
		generic map(
			width => width
		)
		port map(
			clk     => clock,
			A       => adder_in_a,
			B       => adder_in_b,
			rand_in => adder_rand_in,
			S       => adder_out
		);

	--FINISHED signal asserts when hashing is done
	finished_reg <= '1' when CURRENT_STATE = HASH_03_WRITE_HV0 and HASH_ROUND_COUNTER = n_blocks_reg - 1 else '0';
	finished <= finished_reg when rising_edge(clock);

	data_out <= HV_ram_data_in_b;

	-- The reuse is fine, as modules are never active at the same time
	adder_rand_in <= rand_in;
	ch_rand_in    <= rand_in(and_pini_nrnd * WORD_SIZE - 1 downto 0);
	ma_rand_in    <= rand_in(and_pini_nrnd * WORD_SIZE * 2 - 1 downto 0);

	L0_input <= t_shared_flatten(w_window(14), WORD_SIZE);
	L1_input <= t_shared_flatten(w_window(1), WORD_SIZE);

	sha_sigma_L0_gadget_inst : entity work.sha_sigma_L0_gadget
		generic map(
			d => shares
		)
		port map(
			clk     => clock,
			x_input => L0_input,
			out_L0  => L0_output
		);

	sha_sigma_L1_gadget_inst : entity work.sha_sigma_L1_gadget
		generic map(
			d => shares
		)
		port map(
			clk     => clock,
			x_input => L1_input,
			out_L1  => L1_output
		);

	u0_input <= t_shared_flatten(a, WORD_SIZE);

	sha_sigma_u0_gadget_inst : entity work.sha_sigma_u0_gadget
		generic map(
			d => shares
		)
		port map(
			clk     => clock,
			x_input => u0_input,
			out_u0  => u0_output
		);

	u1_input <= t_shared_flatten(e, WORD_SIZE);

	sha_sigma_u1_gadget_inst : entity work.sha_sigma_u1_gadget
		generic map(
			d => shares
		)
		port map(
			clk     => clock,
			x_input => u1_input,
			out_u1  => u1_output
		);

	sha_ch_gadget_inst : entity work.sha_ch_gadget
		generic map(
			d    => shares,
			word => WORD_SIZE
		)
		port map(
			clk     => clock,
			e_input => ch_e_input,
			f_input => ch_f_input,
			g_input => ch_g_input,
			rnd     => ch_rand_in,
			out_ch  => ch_output
		);

	sha_ma_gadget_inst : entity work.sha_ma_gadget
		generic map(
			d    => shares,
			word => WORD_SIZE
		)
		port map(
			clk     => clock,
			a_input => ma_a_input,
			b_input => ma_b_input,
			c_input => ma_c_input,
			rnd     => ma_rand_in,
			out_ma  => ma_output
		);

	a_trans <= t_shared_to_t_shared_trans(a);
	b_trans <= t_shared_to_t_shared_trans(b);
	c_trans <= t_shared_to_t_shared_trans(c);
	d_trans <= t_shared_to_t_shared_trans(d);
	e_trans <= t_shared_to_t_shared_trans(e);
	f_trans <= t_shared_to_t_shared_trans(f);
	g_trans <= t_shared_to_t_shared_trans(g);
	h_trans <= t_shared_to_t_shared_trans(h);
	w0      <= t_shared_to_t_shared_trans(w_window(0));
end architecture;

