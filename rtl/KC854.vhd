--
-- Port to MiSTer by Niels Lueddecke
--
-- Original Copyright notice:
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
-- KC854 Toplevel
--

library IEEE;
use IEEE.std_logic_1164.all;

entity kc854 is
		generic (
			RESET_DELAY : integer := 100000
		);
		port(
		cpuclk			: in  std_logic;		-- 56,75Mhz
		--vgaclk			: in  std_logic;		-- 8,867238Mhz PAL/65MHz VGA
		clkLocked		: in  std_logic;
		reset_sig		: in  std_logic;
		
		ps2_key			: in  std_logic_vector(10 downto 0);
		joystick_0		: in  std_logic_vector(31 downto 0);
		turbo				: in  std_logic_vector(1 downto 0);
		
		scandouble		: in  std_logic;

		ce_pix			: out  std_logic;

		HBlank			: out std_logic;
		HSync				: out std_logic;
		VBlank			: out std_logic;
		VSync				: out std_logic;
		
		VGA_R				: out std_logic_vector(7 downto 0);
		VGA_G				: out std_logic_vector(7 downto 0);
		VGA_B				: out std_logic_vector(7 downto 0);
		
		clk_audio		: in  std_logic;		-- 24.576 MHz
		AUDIO_L			: out std_logic_vector(15 downto 0);
		AUDIO_R			: out std_logic_vector(15 downto 0);
		--AUDIO_S			: out std_logic;
		--AUDIO_MIX		: out std_logic_vector(1 downto 0);
		
		audioEn_n		: in  std_logic;
		tapeEn			: in  std_logic;
		
		LED_USER			: out std_logic;
		LED_POWER		: out std_logic_vector(1 downto 0);
		LED_DISK			: out std_logic_vector(1 downto 0);
		
		USER_OUT			: out std_logic_vector(6 downto 0);
		
		hps_status		: in  std_logic_vector(31 downto 0);
		ioctl_download	: in  std_logic;
		ioctl_index		: in  std_logic_vector(7 downto 0);
		ioctl_wr			: in  std_logic;
		ioctl_addr		: in  std_logic_vector(24 downto 0);
		ioctl_data		: in  std_logic_vector(7 downto 0);
		ioctl_wait		: out  std_logic
    );
end kc854;

architecture struct of kc854 is
	constant NUMINTS		: integer := 2 + 4 + 6 + 2 + 4; -- (M008 + CTC + SIO + PIO + CTC)
	
	signal cpuReset_n		: std_logic;
	signal cpuAddr			: std_logic_vector(15 downto 0);
	signal cpuDataIn		: std_logic_vector(7 downto 0);
	signal cpuDataOut		: std_logic_vector(7 downto 0);
	signal cpuEn			: std_logic;
	signal cpuWait			: std_logic;
	signal cpuTick			: std_logic;
	signal cpuInt_n		: std_logic := '1';
	signal cpuM1_n			: std_logic;
	signal cpuMReq_n		: std_logic;
	signal cpuRfsh_n		: std_logic;
	signal cpuIorq_n		: std_logic;
	signal cpuRD_n			: std_logic;
	signal cpuWR_n			: std_logic;
	signal cpuRETI_n		: std_logic;
	signal cpuIntEna_n	: std_logic;
	
	signal umsr				: std_logic;
	signal afe				: std_logic := '1';			-- 1 for poweron, 0 for reset
	signal cnt_M1_n		: integer range 0 to 15;
	signal cpuM1_n_old	: std_logic;
	
	signal memDataOut		: std_logic_vector(7 downto 0);
	
	signal vidTick			: std_logic;
	signal irm_adr			: std_logic_vector(13 downto 0);
	signal irmPb0_do_2	: std_logic_vector(7 downto 0);
	signal irmCb0_do_2	: std_logic_vector(7 downto 0);
	signal irmPb1_do_2	: std_logic_vector(7 downto 0);
	signal irmCb1_do_2	: std_logic_vector(7 downto 0);
	signal set_img			: std_logic;
	signal set_cmode		: std_logic;
	signal set_blinken	: std_logic;
	signal zi_n				: std_logic;
	signal bi_n				: std_logic;
	signal h4				: std_logic;

	signal ioSel			: boolean;
    
	signal pioCS_n			: std_logic;
	
	signal pioAIn			: std_logic_vector(7 downto 0);
	signal pioAOut			: std_logic_vector(7 downto 0);
	signal pioARdy			: std_logic;
	signal pioAStb			: std_logic;

	signal pioBIn			: std_logic_vector(7 downto 0);
	signal pioBOut			: std_logic_vector(7 downto 0);
	signal pioBRdy			: std_logic;
	signal pioBStb			: std_logic;

	signal pioDataOut		: std_logic_vector(7 downto 0);
	signal pio008DataOut	: std_logic_vector(7 downto 0);
	
	signal pio008CS_n		: std_logic;
	signal pio008AIn		: std_logic_vector(7 downto 0);
	signal pio008AOut		: std_logic_vector(7 downto 0);
	signal pio008ARdy		: std_logic;
	signal pio008AStb		: std_logic;
	signal pio008BIn		: std_logic_vector(7 downto 0);
	signal pio008BOut		: std_logic_vector(7 downto 0);
	signal pio008BRdy		: std_logic;
	signal pio008BStb		: std_logic;

	signal ctcCS_n			: std_logic;
	signal ctcDataOut		: std_logic_vector(7 downto 0);
	signal ctcClkTrg		: std_logic_vector(3 downto 0);
	signal ctcZcTo			: std_logic_vector(3 downto 0);

	signal intPeriph		: std_logic_vector(NUMINTS-1 downto 0);
	signal intAckPeriph	: std_logic_vector(NUMINTS-1 downto 0);
	
	signal resetDelay		: integer range 0 to RESET_DELAY := RESET_DELAY;

	signal ps2_rcvd		: std_logic;
	signal ps2_state		: std_logic;
	signal ps2_code		: std_logic_vector(7 downto 0);
	signal old_stb			: std_logic;

	signal m003DataOut	: std_logic_vector(7 downto 0);
	signal m003Sel			: std_logic;
	signal m003Test		: std_logic_vector(7 downto 0);
	signal m003TestUart	: std_logic;
	signal m003TestRW		: std_logic;
	
	signal vidBlinkEn		: std_logic;

	signal vidTest			: std_logic_vector(3 downto 0);
	
	-- TEMP for MiSTer switches
	signal SW				: std_logic_vector(9 downto 0) := (others => '0');

	-- UART
	signal uartTXD1		: std_logic;
	signal uartTXD2		: std_logic;
	signal uartTXD3		: std_logic;
	signal uartTXDM003	: std_logic;
	signal uartRXDM003	: std_logic;
	
	--KC LEDs MiSTer temp
	signal LEDR				: std_logic_vector(15 downto 0) := (others => '0');
	
	-- TEMP audio_l debug
	signal AUDIO_L_DBG	: std_logic_vector(15 downto 0);
	signal AUDIO_R_DBG	: std_logic_vector(15 downto 0);

begin
	LED_USER <= '0';
	LED_POWER <= b"10";

	-- turn on video output
	--ce_pix <= '1';

	-- reset
	cpuReset_n <= '0' when resetDelay /= 0 else '1';
	
	--USER_OUT(1 downto 0) <= (others => '1');
	--USER_OUT(6 downto 6) <= (others => '1');
	--USER_OUT(0) <= zi_n;
	--USER_OUT(0) <= pioAStb;
	--USER_OUT(1) <= bi_n;
	--USER_OUT(2) <= h4;
	--USER_OUT(6 downto 3) <= ctcZcTo;
	--USER_OUT(6 downto 2) <= (others => '1');
--	USER_OUT(0) <= ioctl_download;
--	USER_OUT(1) <= cpuInt_n;
--	USER_OUT(2) <= bi_n;
	--USER_OUT(3) <= cpuIntEna_n;
--	USER_OUT(4 downto 3) <= not intPeriph(17 downto 16);
--	USER_OUT(6 downto 5) <= not intAckPeriph(17 downto 16);
	--USER_OUT(5 downto 1) <= pioDataOut(4 downto 0) when cpuAddr(7 downto 0) = x"88" and cpuRD_n = '0' and cpuIorq_n = '0' and cpuM1_n='1' else b"11111";
--	USER_OUT(5 downto 1) <= cpuDataOut(4 downto 0) when pioCS_n = '0' and cpuAddr(0) = '0' and cpuAddr(1) = '1' else b"11111";
--	USER_OUT(5 downto 2) <= ioctl_index(3 downto 0);
--	USER_OUT(6) <= pioCS_n when pioCS_n = '0' and cpuAddr(0) = '0' and cpuAddr(1) = '0' else '1';
--	USER_OUT(6 downto 1) <= intAckPeriph(5 downto 0);
	--USER_OUT(6) <= '0' when cpuAddr(7 downto 0) = x"88" and cpuRD_n = '0' and cpuIorq_n = '0' and cpuM1_n='1' else '1';
	--cpuDataOut

	reset : process
	begin
		wait until rising_edge(cpuclk);

		-- delay reset
		if resetDelay > 0 then -- Reset verzoegern?
			resetDelay <= resetDelay - 1;
		end if;

		-- begin reset
		if clkLocked = '0' or reset_sig = '1' then -- Reset
			resetDelay <= RESET_DELAY;
			-- reset vector adr 1 for powerup, 0 for reset
			if clkLocked = '0' then
				afe <= '1';
			else
				afe <= '0';
			end if;
		end if;
		
--		-- 2. Flanke -> startup fertig
		-- some pullup voodoo to make Z80 read initial reset vector from eprom
		-- switch to real addressing after a couple of cycles
		if cnt_M1_n = 2 then
			umsr <= '1';
		end if;
		-- end startup after reading reset vector from rom
		if cpuEn = '1' then
			-- startup according to schematics
			cpuM1_n_old <= cpuM1_n;
			if cpuReset_n = '1' and cpuM1_n_old = '1' and cpuM1_n = '0' and cnt_M1_n < 3 then
				cnt_M1_n <= cnt_M1_n + 1;
			end if;
		end if;
		-- reset cycle counter and address messing signal
		if cpuReset_n = '0' then
			umsr <= '0';
			cnt_M1_n <= 0;
		end if;
	end process;

	-- video controller
	video : entity work.video
		port map (
			clk_sys		=> cpuclk,
			tick_vid		=> vidTick,
			ce_pix		=> ce_pix,

			vgaRed		=> VGA_R,
			vgaGreen		=> VGA_G,
			vgaBlue		=> VGA_B,
			vgaHSync		=> HSync,
			vgaVSync		=> VSync,
			vgaHBlank	=> HBlank,
			vgaVBlank	=> VBlank,
			
			zi_n			=> zi_n,
			bi_n			=> bi_n,
			h4				=> h4,
			
			irm_adr		=> irm_adr,
			irmPb0_do_2	=> irmPb0_do_2,
			irmCb0_do_2	=> irmCb0_do_2,
			irmPb1_do_2	=> irmPb1_do_2,
			irmCb1_do_2	=> irmCb1_do_2,
			
			set_img		=> set_img,
			set_cmode	=> set_cmode,
			set_blinken	=> set_blinken,
			blink			=> ctcZcTo(2)
		);

	-- memory controller
	memcontrol : entity work.memcontrol
		port map (
			clk			=> cpuclk,
			reset_n		=> cpuReset_n,

			cpuAddr		=> cpuAddr,
			cpuDOut		=> memDataOut,
			cpuDIn		=> cpuDataOut,

			cpuWR_n		=> cpuWR_n,
			cpuRD_n		=> cpuRD_n,
			cpuMREQ_n	=> cpuMReq_n,
			cpuM1_n		=> cpuM1_n,
			cpuIORQ_n	=> cpuIorq_n,
			
			umsr			=> umsr,
			afe			=> afe,

			cpuEn			=> cpuEn,
			cpuWait		=> cpuWait,

			cpuTick		=> cpuTick,

			pioPortA		=> pioAOut,
			pioPortB		=> pioBOut,
			
			irm_adr		=> irm_adr,
			irmPb0_do_2	=> irmPb0_do_2,
			irmCb0_do_2	=> irmCb0_do_2,
			irmPb1_do_2	=> irmPb1_do_2,
			irmCb1_do_2	=> irmCb1_do_2,

			set_img		=> set_img,
			set_cmode	=> set_cmode,
			set_blinken	=> set_blinken
		);

	-- CPU data-in multiplexer
	cpuDataIn <= 
			ctcDataOut		when ctcCS_n = '0'		or intAckPeriph(3 downto 0)   /= "0000" else
			pioDataOut		when pioCS_n = '0'		or intAckPeriph(5 downto 4)   /= "00"   else
			pio008DataOut	when pio008CS_n = '0'	or intAckPeriph(17 downto 16) /= "00"   else
			m003DataOut		when m003Sel = '1'		or intAckPeriph(15 downto 6)  /= "0000000000" else
			x"ff"				when ioSel else	-- make other modules play dead
			memDataOut;

	-- T80 CPU
	cpu : entity work.T80se
		generic map(Mode => 1, T2Write => 1, IOWait => 0)
		port map(
			RESET_n => cpuReset_n,
			CLK_n   => cpuclk,
			CLKEN   => cpuEn,
			WAIT_n  => cpuWait,
			INT_n   => cpuInt_n,
			NMI_n   => '1',
			BUSRQ_n => '1',
			M1_n    => cpuM1_n,
			MREQ_n  => cpuMReq_n,
			IORQ_n  => cpuIorq_n,
			RD_n    => cpuRD_n,
			WR_n    => cpuWR_n,
			RFSH_n  => open,
			HALT_n  => open,
			BUSAK_n => open,
			A       => cpuAddr,
			DI      => cpuDataIn,
			DO      => cpuDataOut,
			IntE    => cpuIntEna_n,
			RETI_n  => cpuRETI_n
		);
		
	ioSel   <= cpuIorq_n = '0' and cpuM1_n='1' and (cpuRD_n = '0' or cpuWR_n = '0');

	-- PIO: 88H-8BH
	pioCS_n <= '0' when cpuAddr(7 downto 2) = "100010" and ioSel else '1';

	--pioAStb <= '1';
	pioAIn  <= (others => '1');
	pioBIn  <= (others => '1');

	pio : entity work.pio
		port map (
			clk     => cpuclk,
			res_n   => cpuReset_n,
			dIn     => cpuDataOut,
			dOut    => pioDataOut,
			baSel   => cpuAddr(0),
			cdSel   => cpuAddr(1),
			cs_n    => pioCS_n,
			m1_n    => cpuM1_n,
			iorq_n  => cpuIorq_n,
			rd_n    => cpuRD_n,
			wr_n    => cpuWR_n,
			intAck  => intAckPeriph(5 downto 4),
			int     => intPeriph(5 downto 4),
			aIn     => pioAIn,
			aOut    => pioAOut,
			aRdy    => pioARdy,
			aStb    => pioAStb,
			bIn     => pioBIn,
			bOut    => pioBOut,
			bRdy    => pioBRdy,
			bStb    => pioBStb
		);
	
	-- M008/Joystick PIO: 90H-97BH reserved for M008, here only 90h is used
	pio008CS_n <= '0' when cpuAddr(7 downto 2) = "100100" and ioSel else '1';	-- <---
	--pio008CS_n <= '0' when cpuAddr(7 downto 3) = "10010" and ioSel else '1';
	--pio008CS_n <= '0' when cpuAddr(7 downto 3) = "10010" else '1';
	pio008BIn  <= (others => '1');

--	USER_OUT(0) <= cpuDataOut(7) when ctcCS_n = '0' or pio008CS_n = '0' else '1';
--	USER_OUT(1) <= cpuDataOut(6) when ctcCS_n = '0' or pio008CS_n = '0' else '1';
--	USER_OUT(2) <= cpuDataOut(5) when ctcCS_n = '0' or pio008CS_n = '0' else '1';
--	USER_OUT(3) <= cpuDataOut(4) when ctcCS_n = '0' or pio008CS_n = '0' else '1';
--	USER_OUT(4) <= cpuRD_n when ctcCS_n = '0' or pio008CS_n = '0' else '1';
--	USER_OUT(5) <= pio008CS_n when cpuAddr(7 downto 2) = "100100" else '1';
--	USER_OUT(6) <= ctcCS_n when cpuAddr(7 downto 1) = "1000111" else '1';

	pio_M008 : entity work.pio
		port map (
			clk     => cpuclk,
			res_n   => cpuReset_n,
			dIn     => cpuDataOut,
			dOut    => pio008DataOut,
			baSel   => cpuAddr(0),
			cdSel   => cpuAddr(1),
			cs_n    => pio008CS_n,
			m1_n    => cpuM1_n and cpuReset_n,
			iorq_n  => cpuIorq_n,
			rd_n    => cpuRD_n,
			wr_n    => cpuWR_n,
			intAck  => intAckPeriph(17 downto 16),
			int     => intPeriph(17 downto 16),
			-- fire, fire2, right, left, down, up
			aIn     => b"11" & not joystick_0(4) & not joystick_0(5) & not joystick_0(0) & not joystick_0(1) & not joystick_0(2) & not joystick_0(3),
			aOut    => pio008AOut,
			aRdy    => pio008ARdy,
			aStb    => bi_n,
			bIn     => pio008BIn,
			bOut    => pio008BOut,
			bRdy    => pio008BRdy,
			bStb    => bi_n
		);
	
	-- audio output
	AUDIO_L <= AUDIO_L_DBG;
	AUDIO_R <= AUDIO_R_DBG;
	audio_out : entity work.audio
		port map (
			clk			=> clk_audio,
			reset_n		=> cpuReset_n,
			--AUDIO_L		=> AUDIO_L,
			AUDIO_L		=> AUDIO_L_DBG,
			AUDIO_R		=> AUDIO_R_DBG,
			--AUDIO_S		=> AUDIO_S,
			--AUDIO_MIX	=> AUDIO_MIX,
			audioEn_n	=> audioEn_n,
			tapeEn		=> tapeEn,
			tape_out		=> pioAStb,
			pioB			=> pioBOut,
			ctcTcTo		=> ctcZcTo(1 downto 0)
		);
	
	-- keyboard
	keyboard : entity work.keyboard
		port map (
			clk			=> cpuclk,
			res_n			=> cpuReset_n,
			tick_cpu    => cpuEn,
			turbo    	=> turbo,
			scancode		=> ps2_code,
			scanstate	=> ps2_state,
			rcvd			=> ps2_rcvd,

			remo			=> pioBStb
		);
		
	-- detect pressed key from MiSTer
	process (ps2_key, cpuclk)
	begin
		if rising_edge(cpuclk) then
			old_stb <= ps2_key(10);
			if old_stb /= ps2_key(10) then
				--LED_USER  <= ps2_key(9);
				ps2_state <= ps2_key(9);		-- 1 key down, 0 not down
				ps2_code  <= ps2_key(7 downto 0);
				ps2_rcvd  <= '1';
			else
				ps2_rcvd  <= '0';
			end if;
		end if;
	end process;
	
	-- system clocks
	sysclock : entity work.sysclock
		port map (
			clk      => cpuclk,
			cpuEn    => cpuEn,
			turbo    => turbo,
			tick_cpu => cpuTick,
			tick_vid => vidTick
		);
	
	-- CTC: 8CH-8FH
	ctcCS_n <= '0' when cpuAddr(7 downto 2) = "100011"  and ioSel else '1';

	ctcClkTrg(0) <= h4;
	ctcClkTrg(1) <= h4;
	ctcClkTrg(2) <= bi_n;
	ctcClkTrg(3) <= bi_n;

	ctc : entity work.ctc
		port map (
			clk     => cpuclk,
			sysClkEn => cpuTick,
			res_n   => cpuReset_n,
			cs      => ctcCS_n,
			dIn     => cpuDataOut,
			dOut    => ctcDataOut,
			chanSel => cpuAddr(1 downto 0),
			m1_n    => cpuM1_n,
			iorq_n  => cpuIorq_n,
			rd_n    => cpuRD_n,
			wr_n    => cpuWR_n,
			int     => intPeriph(3 downto 0),
			intAck  => intAckPeriph(3 downto 0),
			clk_trg => ctcClkTrg,
			zc_to   => ctcZcTo
		);
	
	-- tape
	tape : entity work.tape
		port map (
			clk			=> cpuclk,
			reset_n		=> cpuReset_n,
			tick_cpu    => cpuEn,
			LED_DISK		=> LED_DISK,
			tape_out		=> pioAStb,
			turbo    	=> turbo,
			hps_status  => hps_status,
			ioctl_download => ioctl_download,
			ioctl_index => ioctl_index,
			ioctl_wr    => ioctl_wr,
			ioctl_addr  => ioctl_addr,
			ioctl_data  => ioctl_data,
			ioctl_wait  => ioctl_wait
		);

	--m003TestUart <= '1' when (not ctcCS_n='0') else '0';
	m003TestUart <= '1';
	--m003TestRW <= (cpuRD_n and cpuWR_n);
	m003TestRW <= '1';

	uart1 : entity work.uart
		generic map (
			BAUDRATE => 2_000_000
		)
		port map (
			clk     => cpuclk,
			cs_n    => m003TestUart,
			rd_n    => '1',
			wr_n    => m003TestRW,
			addr    => "0",
			dIn     => cpuAddr(7 downto 0),
			dOut    => open,
			txd     => uartTXD1,
			rxd     => '1'
		);

	uart2 : entity work.uart
		generic map (
			BAUDRATE => 2_000_000
		)
		port map (
			clk     => cpuclk,
			cs_n    => m003TestUart,
			rd_n    => '1',
			wr_n    => cpuRD_n,
			addr    => "0",
			dIn     => cpuDataIn,
			dOut    => open,
			txd     => uartTXD2,
			rxd     => '1'
		);

	uart3 : entity work.uart
		generic map (
			BAUDRATE => 2_000_000
		)
		port map (
			clk     => cpuclk,
			cs_n    => m003TestUart,
			rd_n    => '1',
			wr_n    => cpuWR_n,
			addr    => "0",
			dIn     => cpuDataOut,
			dOut    => open,
			txd     => uartTXD3,
			rxd     => '1'
		);
 
	-- interrupt controller
	intController : entity work.intController
		generic map (
			NUMINTS => NUMINTS
		)
		port map (
			clk       => cpuclk,
			res_n     => cpuReset_n,
			int_n     => cpuInt_n,
			intPeriph => intPeriph,
			intAck    => intAckPeriph,
			m1_n      => cpuM1_n,
			iorq_n    => cpuIorq_n,
			rd_n      => cpuRD_n,
			reti_n    => cpuRETI_n,
			intEna_n  => cpuIntEna_n
		);
    
	m003 : entity work.m003
		port map (
			clk      => cpuclk,
			sysClkEn => cpuTick,

			res_n    => cpuReset_n,

			addr     => cpuAddr,
			dIn      => cpuDataOut,
			dOut     => m003DataOut,

			modSel   => m003Sel,
			modEna   => LEDR(9),

			m1_n     => cpuM1_n,
			mreq_n   => cpuMREQ_n,
			iorq_n   => cpuIORQ_n,
			rd_n     => cpuRD_n,
			wr_n     => cpuWR_n,

			int      => intPeriph(15 downto 6),
			intAck   => intAckPeriph(15 downto 6),

			divideBy2 => SW(2),
			aRxd     => '1',
			aTxd     => open,
			bRxd     => uartRXDM003,
			bTxd     => uartTXDM003,

			test     => m003Test
		);
end;
