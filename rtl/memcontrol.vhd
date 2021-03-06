--
-- complete rewrite by Niels Lueddecke in 2021
--
-- Copyright (c) 2015, $ME
-- All rights reserved.
--
-- Redistribution and use in source and synthezised forms, with or without modification, are permitted 
-- provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice, this list of conditions 
--    and the following disclaimer.
--
-- 2. Redistributions in synthezised form must reproduce the above copyright notice, this list of conditions
--    and the following disclaimer in the documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED 
-- WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A 
-- PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR 
-- ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
-- TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
-- NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
-- POSSIBILITY OF SUCH DAMAGE.
--
--
-- Speicher-Controller fuer KC85/4
--   fuer SRAM mit 256kx16
library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity memcontrol is
	port (
		clk				: in  std_logic;
		reset_n			: in  std_logic;

		cpuAddr			: in  std_logic_vector(15 downto 0);
		cpuDOut			: out std_logic_vector(7 downto 0);
		cpuDIn			: in  std_logic_vector(7 downto 0);

		cpuWR_n			: in  std_logic;
		cpuRD_n			: in  std_logic;
		cpuM1_n			: in  std_logic;
		cpuMREQ_n		: in  std_logic;
		cpuIORQ_n		: in  std_logic;

		cpuEn				: out std_logic;
		cpuWait			: out std_logic;
		
		memCS_n			: out std_logic;

		cpuTick			: in  std_logic;

		umsr				: in  std_logic;
		afe				: in  std_logic;

		pioPortA			: in  std_logic_vector(7 downto 0);
		pioPortB			: in  std_logic_vector(7 downto 0);
		
		irm_adr			: in std_logic_vector(13 downto 0);
		irmPb0_do_2		: out std_logic_vector(7 downto 0);
		irmCb0_do_2		: out std_logic_vector(7 downto 0);
		irmPb1_do_2		: out std_logic_vector(7 downto 0);
		irmCb1_do_2		: out std_logic_vector(7 downto 0);
				 
		set_img			: out std_logic;
		set_cmode		: out std_logic;
		set_blinken		: out std_logic
	);
end memcontrol;

architecture rtl of memcontrol is
	type   state_type is ( idle, read_wait, do_read );
	signal mem_state    		: state_type := idle;
	
	-- ram temp signals
	signal tmp_adr				: std_logic_vector(15 downto 0);
	signal tmp_data_in		: std_logic_vector(7 downto 0);
	
	-- memory config ports
	signal port84				: std_logic_vector(7 downto 0);
	signal port86				: std_logic_vector(7 downto 0);
	
	-- ram
	signal ram_do				: std_logic_vector(7 downto 0);
	signal ram_we_n			: std_logic;
	signal ram_raf				: std_logic_vector(3 downto 0) := x"0";

	-- ram IRM Pixel Bild 0 (Bildwiederholspeicher)
	signal irmPb0_do_1		: std_logic_vector(7 downto 0);
	signal irmPb0_wr_n_1		: std_logic;

	-- ram IRM Color Bild 0 (Bildwiederholspeicher)
	signal irmCb0_do_1		: std_logic_vector(7 downto 0);
	signal irmCb0_wr_n_1		: std_logic;

	-- ram IRM Pixel Bild 1 (Bildwiederholspeicher)
	signal irmPb1_do_1		: std_logic_vector(7 downto 0);
	signal irmPb1_wr_n_1		: std_logic;

	-- ram IRM Color Bild 1 (Bildwiederholspeicher)
	signal irmCb1_do_1		: std_logic_vector(7 downto 0);
	signal irmCb1_wr_n_1		: std_logic;
	
	-- rom
	signal rom_data    		: std_logic_vector(7 downto 0);
	signal romC_caos_data	: std_logic_vector(7 downto 0);
	signal romC_basic_data	: std_logic_vector(7 downto 0);
	signal romE_caos_data	: std_logic_vector(7 downto 0);
	signal romE_caos_adr		: std_logic_vector(12 downto 0);
	
	signal sig_dbg				: std_logic_vector(15 downto 0);
	
	-- memory control signals
	signal pioPortA_rdy		: std_logic := '0';
	signal ram0_en				: std_logic := '1';
	signal ram0_wp				: std_logic := '1';
	signal ram4_en				: std_logic := '0';
	signal ram4_wp				: std_logic := '0';
	signal ram8_en				: std_logic := '0';
	signal ram8_wp				: std_logic := '0';
	signal ram8_raf			: std_logic_vector(3 downto 0) := x"0";
	signal romC_caos_en		: std_logic := '0';
	signal romC_basic_en		: std_logic := '1';
	signal romE_caos_en		: std_logic := '1';
	signal irm					: std_logic := '1';

begin

	memCS_n <= 
		'0' when cpuMREQ_n='0' and cpuRD_n='0' and cpuAddr(15 downto 14) = b"00"  and ram0_en = '1' else	-- ram 0
		'0' when cpuMREQ_n='0' and cpuRD_n='0' and cpuAddr(15 downto 14) = b"01"  and ram4_en = '1' else	-- ram 4
		'0' when cpuMREQ_n='0' and cpuRD_n='0' and cpuAddr(15 downto 14) = b"10"  and ram8_en = '1' else	-- ram 8
		'0' when cpuMREQ_n='0' and cpuRD_n='0' and cpuAddr(15 downto 14) = b"10"  and irm = '1'     else	-- irm
		'0' when cpuMREQ_n='0' and cpuRD_n='0' and cpuAddr(15 downto 13) = b"110" and romC_caos_en  = '1' else	-- rom caos c
		'0' when cpuMREQ_n='0' and cpuRD_n='0' and cpuAddr(15 downto 13) = b"110" and romC_basic_en = '1' else	-- rom user
		'0' when cpuMREQ_n='0' and cpuRD_n='0' and cpuAddr(15 downto 13) = b"111" and romE_caos_en  = '1' else	-- rom caos e
		'1';
	
	-- serve cpu
	cpuserv : process
	begin
		wait until rising_edge(clk);
		
		cpuWait	<= '1';
		cpuEn		<= '0';
		
		if reset_n = '0' then
			mem_state <= idle;
		end if;
		
		if pioPortA_rdy = '0' then
			romE_caos_en	<= '1';
			ram0_en			<= '1';
			irm				<= '1';
			ram0_wp			<= '1';
			romC_basic_en	<= '1';
		else
			romE_caos_en	<= pioPortA(0);
			ram0_en			<= pioPortA(1);
			irm				<= pioPortA(2);
			ram0_wp			<= pioPortA(3);
			romC_basic_en	<= pioPortA(7);
		end if;
		ram8_en			<= pioPortB(5);
		ram8_wp			<= pioPortB(6);
		ram8_raf			<= port84(7 downto 4);
		ram4_en			<= port86(0);
		ram4_wp			<= port86(1);
		romC_caos_en	<= port86(7);
		
		-- set image to display and color mode
		set_img     <= port84(0);
		set_cmode   <= port84(3);
		set_blinken <= pioPortB(7);
		
		-- disable wr_n's by default
		ram_we_n      <= '1';
		irmPb0_wr_n_1 <= '1';
		irmCb0_wr_n_1 <= '1';
		irmPb1_wr_n_1 <= '1';
		irmCb1_wr_n_1 <= '1';
		
		-- memory state machine
		case mem_state is
			when idle =>
				if (reset_n='0') then
					port84 <= (others => '0');
					port86 <= (others => '0');
					romE_caos_adr <= afe & x"000";
					cpuDOut <= romE_caos_data;	-- ROM CAOS E reset vector
				elsif cpuTick = '1' then
					ram_raf <= ram8_raf;
					-- write to io port 84/86
					if		(cpuIORQ_n = '0' and cpuM1_n = '1' and cpuWR_n = '0') then
						case cpuAddr(7 downto 0) is
							when x"84"|x"85" => port84 <= cpuDIn;
							when x"86"|x"87" => port86 <= cpuDIn;
							when x"88" => pioPortA_rdy <= '1';
							when others => null;
						end case;
						mem_state <= idle;
						cpuEn		 <= '1';
					-- write memory
					elsif (cpuMREQ_n = '0' and cpuWR_n = '0') then
						mem_state	<= idle;
						cpuEn			<= '1';
						tmp_adr		<= cpuAddr;
						tmp_data_in <= cpuDIn;
						-- ram0/4 write decide which WR_en to strobe
						if		cpuAddr(15 downto 14) = b"00" and ram0_en = '1' and ram0_wp = '1' then
							ram_we_n   <= '0';		-- ram0
							ram_raf    <= x"e";
						elsif	cpuAddr(15 downto 14) = b"01" and ram4_en = '1' and ram4_wp = '1' then
							ram_we_n   <= '0';		-- ram4
							ram_raf    <= x"f";
						elsif cpuAddr(15 downto 14) = b"10" and irm = '1' then
							-- Bildspeicher/systemspeicher in Bild0/Pixel, or 'hidden' system memory areas in irm
							if cpuAddr < x"a800" or (romE_caos_en  = '0' and romC_caos_en  = '1') then
								-- irm write decide which WR_en to strobe
								if		port84(1) = '1' and port84(2) = '0' then irmCb0_wr_n_1 <= '0';		-- Bild 0, Color
								elsif	port84(1) = '0' and port84(2) = '0' then irmPb0_wr_n_1 <= '0';		-- Bild 0, Pixel
								elsif	port84(1) = '1' and port84(2) = '1' then irmCb1_wr_n_1 <= '0';		-- Bild 1, Color
								elsif	port84(1) = '0' and port84(2) = '1' then irmPb1_wr_n_1 <= '0';		-- Bild 1, Pixel
								end if;
							else
								irmPb0_wr_n_1 <= '0';	-- Systemspeicher in Bild0/Pixel
							end if;
						-- ram8
						elsif cpuAddr(15 downto 14) = b"10" and ram8_en = '1' and ram8_wp = '1' then ram_we_n <= '0';	-- ram8
						end if;
					-- read memory
					elsif (cpuMREQ_n='0' and cpuRD_n='0') then
						mem_state <= read_wait;
						tmp_adr   <= cpuAddr;
						if umsr = '0' then
							-- boot, modify cpu address to point to caos romE, afe differ between poweron and reset button
							romE_caos_adr <= afe & x"0" & cpuAddr(7 downto 0);
						else
							-- normal operation, pass cpu address to caos romE unmodified
							romE_caos_adr <= cpuAddr(12 downto 0);
						end if;
						-- ram0/4 raf
						if		cpuAddr(15 downto 14) = b"00" then ram_raf <= x"e";	-- ram0
						elsif	cpuAddr(15 downto 14) = b"01" then ram_raf <= x"f";	-- ram4
						end if;
					else
						-- short cycle, nothing for memory to do
						mem_state <= idle;
						cpuEn		 <= '1';
					end if;
				end if;
			when read_wait =>
				mem_state <= do_read;
			when do_read =>
				mem_state <= idle;
				cpuEn		 <= '1';
				-- decide which DO to send to cpu
				if umsr = '0' then
					-- startup, pass caos romE data to cpu
					cpuDOut <= romE_caos_data;
				else
					-- after startup, decide which DO to send to cpu
					if		tmp_adr(15 downto 14) = b"00"  and ram0_en       = '1' then cpuDOut <= ram_do;				-- ram0
					elsif	tmp_adr(15 downto 14) = b"01"  and ram4_en       = '1' then cpuDOut <= ram_do;				-- ram4
					elsif	tmp_adr(15 downto 13) = b"110" and romC_caos_en  = '1' then cpuDOut <= romC_caos_data;		-- ROM CAOS C
					elsif	tmp_adr(15 downto 13) = b"110" and romC_basic_en = '1' then cpuDOut <= romC_basic_data;	-- ROM BASIC
					elsif	tmp_adr(15 downto 13) = b"111" and romE_caos_en  = '1' then cpuDOut <= romE_caos_data;		-- ROM CAOS E
					elsif tmp_adr(15 downto 14) = b"10"  and irm = '1' then
						-- Bildspeicher/systemspeicher in Bild0/Pixel, or 'hidden' system memory areas in irm
						if tmp_adr < x"a800" or (romE_caos_en  = '0' and romC_caos_en  = '1') then
							-- irm read decide what DO to send
							if		port84(1)   = '1' and port84(2) = '0' then cpuDOut <= irmCb0_do_1;	-- Bild 0, Color
							elsif	port84(1)   = '0' and port84(2) = '0' then cpuDOut <= irmPb0_do_1;	-- Bild 0, Pixel
							elsif	port84(1)   = '1' and port84(2) = '1' then cpuDOut <= irmCb1_do_1;	-- Bild 1, Color
							elsif	port84(1)   = '0' and port84(2) = '1' then cpuDOut <= irmPb1_do_1;	-- Bild 1, Pixel
							end if;
						else
							cpuDOut <= irmPb0_do_1;		-- Systemspeicher in Bild0/Pixel
						end if;
					elsif tmp_adr(15 downto 14) = b"10" and ram8_en = '1' then cpuDOut <= ram_do;		-- ram8
					-- pullups auf d0-d7
					else
						cpuDOut <= x"ff";
					end if;
				end if;
			end case;
	end process;
	
	-- ram, 256kb
	sram_ram : entity work.sram
		generic map (
			AddrWidth => 18,		-- kc85/5 
			DataWidth => 8
		)
		port map (
			clk  => clk,
			addr => ram_raf(3 downto 0) & tmp_adr(13 downto 0),
			din  => tmp_data_in,
			dout => ram_do,
			ce_n => '0', 
			we_n => ram_we_n
		);
	
	-- irmPb0
	irmPb0 : entity work.dualsram
		generic map (
			AddrWidth => 14
		)
		port map (
			clk1  => clk,
			addr1 => tmp_adr(13 downto 0),
			din1  => tmp_data_in,
			dout1 => irmPb0_do_1,
			cs1_n => '0', 
			wr1_n => irmPb0_wr_n_1,

			clk2  => clk,
			addr2 => irm_adr,
			din2  => (others => '0'),
			dout2 => irmPb0_do_2,
			cs2_n => '0',
			wr2_n => '1'
		);
		
	-- irmCb0
	irmCb0 : entity work.dualsram
		generic map (
			AddrWidth => 14
		)
		port map (
			clk1  => clk,
			addr1 => tmp_adr(13 downto 0),
			din1  => tmp_data_in,
			dout1 => irmCb0_do_1,
			cs1_n => '0', 
			wr1_n => irmCb0_wr_n_1,

			clk2  => clk,
			addr2 => irm_adr,
			din2  => (others => '0'),
			dout2 => irmCb0_do_2,
			cs2_n => '0',
			wr2_n => '1'
		);
		
	-- irmPb1
	irmPb1 : entity work.dualsram
		generic map (
			AddrWidth => 14
		)
		port map (
			clk1  => clk,
			addr1 => tmp_adr(13 downto 0),
			din1  => tmp_data_in,
			dout1 => irmPb1_do_1,
			cs1_n => '0', 
			wr1_n => irmPb1_wr_n_1,

			clk2  => clk,
			addr2 => irm_adr,
			din2  => (others => '0'),
			dout2 => irmPb1_do_2,
			cs2_n => '0',
			wr2_n => '1'
		);
		
	-- irmCb1
	irmCb1 : entity work.dualsram
		generic map (
			AddrWidth => 14
		)
		port map (
			clk1  => clk,
			addr1 => tmp_adr(13 downto 0),
			din1  => tmp_data_in,
			dout1 => irmCb1_do_1,
			cs1_n => '0', 
			wr1_n => irmCb1_wr_n_1,

			clk2  => clk,
			addr2 => irm_adr,
			din2  => (others => '0'),
			dout2 => irmCb1_do_2,
			cs2_n => '0',
			wr2_n => '1'
		);
	
	-- caos 47 c
	caos_c : entity work.caos47_c
		port map (
			clk => clk,
			addr => tmp_adr(12 downto 0),
			data => romC_caos_data
		);
	
	-- user 47 c
	basic : entity work.user47_c
		port map (
			clk => clk,
			addr => port86(6 downto 5) & tmp_adr(12 downto 0),
			data => romC_basic_data
		);

	-- caos 47 e
	caos_e : entity work.caos47_e
		port map (
			clk => clk,
			addr => romE_caos_adr,
			data => romE_caos_data
		);
	
--	-- caos 42 c
--	caos_c : entity work.caos_c
--		port map (
--			clk => clk,
--			addr => tmp_adr(11 downto 0),
--			data => romC_caos_data
--		);
--	
--	-- basic 42 c
--	basic : entity work.basic
--		port map (
--			clk => clk,
--			addr => tmp_adr(12 downto 0),
--			data => romC_basic_data
--		);
--
--	-- caos 42 e
--	caos_e : entity work.caos_e
--		port map (
--			clk => clk,
--			addr => romE_caos_adr,
--			data => romE_caos_data
--		);
end;
