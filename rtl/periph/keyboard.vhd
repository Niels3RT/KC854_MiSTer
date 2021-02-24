--
-- some things rewritten to suit MiSTer keyboard input Niels Lueddecke in 2021
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
-- Keyboard Keymapping und Transmit-Logik
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all; 

entity keyboard is
		generic (
			SYSCLK : integer := 50_000_000
		);
		port (
			clk				: in std_logic;
			res_n				: in std_logic;

			turbo				: in  std_logic_vector(1 downto 0);

			scancode			: in std_logic_vector(7 downto 0);
			scanstate		: in std_logic;
			rcvd				: in std_logic;

			remo				: out std_logic
		);
end keyboard;

architecture rtl of keyboard is
	--constant MAX_DIV			: integer := SYSCLK / (62_5) * 64 - 1;
	--constant c_MAX_DIV		: unsigned(31 downto 0) := x"00000000" + SYSCLK / (62_5) * 64 - 1;
	--constant c_MAX_DIV		: unsigned(31 downto 0) := x"00000000" + SYSCLK / 1060 - 1;		--1060hz, 1x gut nicht perfekt, 2x perfekt,  4x wwwwwww, 8x perfekt
	--constant c_MAX_DIV		: unsigned(31 downto 0) := x"00000000" + SYSCLK / 1024 - 1;		--1024hz, in original fpga implementation, 1x nicht perfekt, 2x sehr gut, 4x wwww, 8x fast sehr gut
	--constant c_MAX_DIV		: unsigned(31 downto 0) := x"00000000" + SYSCLK / 1000 - 1;		--1000hz, 1x nicht perfekt, 2x perfekt, 4x gut aber fehler, 8x sehr gut
	--constant c_MAX_DIV		: unsigned(31 downto 0) := x"00000000" + SYSCLK / 976 - 1;		--1024us, KC82/2 kbd Handbuch, 1x nicht perfekt, 2x sehr gut, 4x sehr gut, 8x keine fkt
	--constant c_MAX_DIV		: unsigned(31 downto 0) := x"00000000" + SYSCLK / 1000 - 1;		--950hz, 1x gut, 2x gut, 4x gut aber fehler, 8x perfekt
	
	signal MAX_DIV				: unsigned(31 downto 0) := (others => '0');

	--signal clockDiv			: integer range 0 to MAX_DIV := 0;
	signal clockDiv			: unsigned(31 downto 0) := (others => '0');
	--  5: 0 Bit
	--  7: 1 Bit
	-- 14: Wortabstand
	-- 19: Doppelwortabstand
	signal pulseCnt			: integer range 0 to 18 := 0;

	signal keyClockEn			: boolean;

	signal keyShift			: std_logic_vector(7 downto 0) := "00000000";
	signal currentKey			: std_logic_vector(7 downto 0);

	signal key					: std_logic_vector(7 downto 0);
	signal key_cnt				: unsigned(3 downto 0) := x"0";
	signal key_cnt_old		: unsigned(3 downto 0) := x"0";

	signal rshift				: boolean := false;
	signal lshift				: boolean := false;
	signal altkey				: boolean := false;

	signal keydown				: boolean;
	signal keydownDelayed	: boolean;
	signal keyup				: boolean;
	signal keyupDelayed		: boolean;
	signal keyRepeat			: integer range 0 to 2 := 0;
	signal keycode				: std_logic_vector(7 downto 0);
	signal keycode_last		: std_logic_vector(7 downto 0);

	signal key_repeat_cnt	: unsigned(31 downto 0) := (others => '0');
	signal key_repeat_state	: std_logic := '0';

	signal iKey					: integer range 0 to 128 := 0;

	signal turbo_old			: std_logic_vector(1 downto 0) := b"00";

begin
    
	keystates : process
	begin
		wait until rising_edge(clk);
		
		keydown <= false;
		keyup   <= false;
		
		if (rcvd = '1') then
			if (scancode = x"59") then -- shift rechts
				if scanstate = '1' then
					rshift <= true;
				else
					rshift <= false;
				end if;
			elsif (scancode = x"12") then -- shift links
				if scanstate = '1' then
					lshift <= true;
				else
					lshift <= false;
				end if;
			elsif (scancode = x"11") then -- alt / alt gr
				if scanstate = '1' then
					altkey <= true;
				else
					altkey <= false;
				end if;
			elsif (scancode /= x"e0" and scancode /= x"e1") then -- e0/e1 ignorieren
				if scanstate = '1' then
					if keycode_last /= scancode then
						keydown <= true;
						keycode <= scancode;
					end if;
				else
					keyup <= true;
					keycode_last <= x"00";
				end if;
			end if;
		end if;
	end process;
 
    decodekeys : process
        variable shift : std_logic;
        variable alt   : std_logic;
    begin
        wait until rising_edge(clk);
        
        shift := '1';
        if (lshift or rshift) then
            shift := '0';
        end if;
     
        alt := '0';
        if (altkey) then
            alt := '1';
        end if;
        
        keydownDelayed <= keydown;
		  keyupDelayed   <= keyup;
     
        case alt & shift & keycode is
            when '0' & '0' & x"1d"  => iKey <= 0;   -- W
            when '0' & '1' & x"1d"  => iKey <= 1;   -- w
            when '0' & '0' & x"1c"  => iKey <= 2;   -- A
            when '0' & '1' & x"1c"  => iKey <= 3;   -- a
            when '0' & '0' & x"1e"  => iKey <= 4;   -- 2
            when '0' & '1' & x"1e"  => iKey <= 5;   -- "
            when '0' & '0' & x"6b"  => iKey <= 6;   -- Cursor links
            when '0' & '1' & x"6b"  => iKey <= 7;   -- CCR
            when '0' & '0' & x"6c"  => iKey <= 8;   -- Home
            when '0' & '1' & x"6c"  => iKey <= 9;   -- CLS
            when '0' & '0' & x"07"  => iKey <= 8;   -- F12 -> Home
            when '0' & '1' & x"07"  => iKey <= 9;   -- F12 -> CLS
            when '0' & '0' & x"45"  => iKey <= 10;  -- =
            when '0' & '1' & x"4a"  => iKey <= 11;  -- -
            when '0' & '0' & x"06"  => iKey <= 12;  -- F2
            when '0' & '1' & x"06"  => iKey <= 13;  -- F8
            when '0' & '0' & x"1a"  => iKey <= 14;  -- Y
            when '0' & '1' & x"1a"  => iKey <= 15;  -- y
            when '0' & '0' & x"24"  => iKey <= 16;  -- E
            when '0' & '1' & x"24"  => iKey <= 17;  -- e
            when '0' & '0' & x"1b"  => iKey <= 18;  -- S
            when '0' & '1' & x"1b"  => iKey <= 19;  -- s
            when '0' & '1' & x"5d"  => iKey <= 20;  -- #
            when '0' & '1' & x"26"  => iKey <= 21;  -- 3
            when '0' & '0' & x"0e"  => iKey <= 22;  -- ]
            when '0' & '1' & x"0e"  => iKey <= 23;  -- ^
            when '0' & '0' & x"78"  => iKey <= 24;  -- CLR -> F11
            when '0' & '1' & x"78"  => iKey <= 25;  -- CLR -> F11
            when '0' & '0' & x"5b"  => iKey <= 26;  -- *
            when '0' & '0' & x"49"  => iKey <= 27;  -- :
            when '0' & '0' & x"04"  => iKey <= 28;  -- F3
            when '0' & '1' & x"04"  => iKey <= 29;  -- F3
            when '0' & '0' & x"22"  => iKey <= 30;  -- X
            when '0' & '1' & x"22"  => iKey <= 31;  -- x
            when '0' & '0' & x"2c"  => iKey <= 32;  -- T
            when '0' & '1' & x"2c"  => iKey <= 33;  -- t
            when '0' & '0' & x"2b"  => iKey <= 34;  -- F
            when '0' & '1' & x"2b"  => iKey <= 35;  -- f
            when '0' & '0' & x"2e"  => iKey <= 36;  -- 5
            when '0' & '1' & x"2e"  => iKey <= 37;  -- %
            when '0' & '0' & x"4d"  => iKey <= 38;  -- P
            when '0' & '1' & x"4d"  => iKey <= 39;  -- p
            when '0' & '0' & x"71"  => iKey <= 40;  -- DEL (ENTF)
            when '0' & '1' & x"71"  => iKey <= 41;  -- 
            when '0' & '0' & x"66"  => iKey <= 40;  -- DEL (Backspace)
            when '0' & '1' & x"66"  => iKey <= 41;  --
            when '0' & '0' & x"09"  => iKey <= 40;  -- F10 -> DEL
            when '0' & '1' & x"09"  => iKey <= 41;  --
            when '1' & '1' & x"15"  => iKey <= 42;  -- @ (Alt (Gr)+Q)
            when '0' & '1' & x"45"  => iKey <= 43;  -- 0
            when '0' & '0' & x"03"  => iKey <= 44;  -- F5
            when '0' & '1' & x"03"  => iKey <= 45;  --  
            when '0' & '0' & x"2a"  => iKey <= 46;  -- V
            when '0' & '1' & x"2a"  => iKey <= 47;  -- v
            when '0' & '0' & x"3c"  => iKey <= 48;  -- U
            when '0' & '1' & x"3c"  => iKey <= 49;  -- u
            when '0' & '0' & x"33"  => iKey <= 50;  -- H
            when '0' & '1' & x"33"  => iKey <= 51;  -- h
            when '0' & '1' & x"55"  => iKey <= 52;  -- ´            
            when '0' & '1' & x"3d"  => iKey <= 53;  -- 7
            when '0' & '0' & x"44"  => iKey <= 54;  -- O
            when '0' & '1' & x"44"  => iKey <= 55;  -- o
            when '0' & '0' & x"70"  => iKey <= 56;  -- INS
            when '0' & '1' & x"70"  => iKey <= 57;  --
            when '0' & '0' & x"01"  => iKey <= 56;  -- F9 -> INS
            when '0' & '1' & x"01"  => iKey <= 57;  -- 
            when '0' & '0' & x"46"  => iKey <= 58;  -- 9
            when '0' & '1' & x"46"  => iKey <= 59;  -- )
            when '0' & '0' & x"77"  => iKey <= 60;  -- BRK
            when '0' & '1' & x"77"  => iKey <= 61;  --
            when '0' & '0' & x"83"  => iKey <= 60;  -- F7 -> BRK
            when '0' & '1' & x"83"  => iKey <= 61;  -- 
            when '0' & '0' & x"31"  => iKey <= 62;  -- N
            when '0' & '1' & x"31"  => iKey <= 63;  -- n
            when '0' & '0' & x"43"  => iKey <= 64;  -- I
            when '0' & '1' & x"43"  => iKey <= 65;  -- i
            when '0' & '0' & x"3b"  => iKey <= 66;  -- J
            when '0' & '1' & x"3b"  => iKey <= 67;  -- j
            when '0' & '0' & x"3e"  => iKey <= 68;  -- 8
            when '0' & '1' & x"3e"  => iKey <= 69;  -- (
            when '0' & '0' & x"29"  => iKey <= 70;  -- SPC
            when '0' & '1' & x"29"  => iKey <= 71;  -- 
            when '0' & '0' & x"42"  => iKey <= 72;  -- K
            when '0' & '1' & x"42"  => iKey <= 73;  -- k
            when '0' & '1' & x"61"  => iKey <= 74;  -- <            
            when '0' & '1' & x"41"  => iKey <= 75;  -- ,
            when '0' & '0' & x"76"  => iKey <= 76;  -- ESC
            when '0' & '1' & x"76"  => iKey <= 77;  -- STOP
            when '0' & '0' & x"0a"  => iKey <= 76;  -- F8 (STOP/ESC)
            when '0' & '1' & x"0a"  => iKey <= 77;  -- 
            when '0' & '0' & x"3a"  => iKey <= 78;  -- M
            when '0' & '1' & x"3a"  => iKey <= 79;  -- m
            when '0' & '0' & x"35"  => iKey <= 80;  -- Z
            when '0' & '1' & x"35"  => iKey <= 81;  -- z
            when '0' & '0' & x"34"  => iKey <= 82;  -- G
            when '0' & '1' & x"34"  => iKey <= 83;  -- g
            when '0' & '0' & x"36"  => iKey <= 84;  -- 6
            when '0' & '1' & x"36"  => iKey <= 85;  -- &
     --           when '0' & '0' & x"??"  => iKey <= 86;  -- 
     --           when '0' & '1' & x"??"  => iKey <= 87;  -- 
            when '0' & '0' & x"4b"  => iKey <= 88;  -- L
            when '0' & '1' & x"4b"  => iKey <= 89;  -- l
            when '0' & '0' & x"61"  => iKey <= 90;  -- >            
            when '0' & '1' & x"49"  => iKey <= 91;  -- .
            when '0' & '0' & x"0b"  => iKey <= 92;  -- F6
            when '0' & '1' & x"0b"  => iKey <= 93;  -- 
            when '0' & '0' & x"32"  => iKey <= 94;  -- B
            when '0' & '1' & x"32"  => iKey <= 95;  -- b
            when '0' & '0' & x"2d"  => iKey <= 96;  -- R
            when '0' & '1' & x"2d"  => iKey <= 97;  -- r
            when '0' & '0' & x"23"  => iKey <= 98;  -- D
            when '0' & '1' & x"23"  => iKey <= 99;  -- d
            when '0' & '0' & x"25"  => iKey <= 100; -- 4
            when '0' & '1' & x"25"  => iKey <= 101; -- $
            when '0' & '0' & x"5d"  => iKey <= 102; -- |
            when '1' & '1' & x"61"  => iKey <= 102; -- |           
            when '0' & '0' & x"4a"  => iKey <= 103; -- _
            when '0' & '0' & x"41"  => iKey <= 104; -- ;            
            when '0' & '1' & x"5b"  => iKey <= 105; -- +
            when '0' & '0' & x"4e"  => iKey <= 106; -- ?
            when '0' & '0' & x"3d"  => iKey <= 107; -- /
            when '0' & '0' & x"0c"  => iKey <= 108; -- F4
            when '0' & '1' & x"0c"  => iKey <= 109; -- 
            when '0' & '0' & x"21"  => iKey <= 110; -- C
            when '0' & '1' & x"21"  => iKey <= 111; -- c
            when '0' & '0' & x"15"  => iKey <= 112; -- Q
            when '0' & '1' & x"15"  => iKey <= 113; -- q
            when '0' & '0' & x"58"  => iKey <= 114; -- Shift Lock
            when '0' & '1' & x"58"  => iKey <= 115; -- 
            when '0' & '0' & x"16"  => iKey <= 116; -- 1
            when '0' & '1' & x"16"  => iKey <= 117; -- !
            when '0' & '0' & x"72"  => iKey <= 118; -- Cursor down
            when '0' & '1' & x"72"  => iKey <= 119; -- 
            when '0' & '0' & x"75"  => iKey <= 120; -- Cursor up
            when '0' & '1' & x"75"  => iKey <= 121; -- 
            when '0' & '0' & x"74"  => iKey <= 122; -- Cursor rechts
            when '0' & '1' & x"74"  => iKey <= 123; -- 
            when '0' & '0' & x"05"  => iKey <= 124; -- F1
            when '0' & '1' & x"05"  => iKey <= 125; -- 
            when '0' & '0' & x"5a"  => iKey <= 126; -- <Enter>
            when '0' & '1' & x"5a"  => iKey <= 127; -- 
            when others => iKey <= 128; -- no key
        end case;
    end process;
		
	-- clock fuer ausgang -> 1024Hz
	divider : process
	begin
		wait until rising_edge(clk);
		
		-- divide clock for kbd interface
		if (clockDiv < MAX_DIV) then
			clockDiv <= clockDiv + 1;
			keyClockEn <= false;
		else
			clockDiv <= x"00000000";
			keyClockEn <= true;
		end if;

		-- set divider by turbo setting
		if		turbo = b"00" then			-- 1x
			--MAX_DIV	<= c_MAX_DIV;
			MAX_DIV	<= x"00000000" + SYSCLK / 976 - 1;		-- 976
		elsif	turbo = b"01" then			-- 2x
			--MAX_DIV	<= b"0" & c_MAX_DIV(31 downto 1);
			MAX_DIV	<= x"00000000" + SYSCLK / 2000 - 1;		-- 1000
		elsif	turbo = b"10" then			-- 4x
			--MAX_DIV	<= b"00" & c_MAX_DIV(31 downto 2);
			MAX_DIV	<= x"00000000" + SYSCLK / 3904 - 1;		-- 976
		elsif	turbo = b"11" then			-- 8x
			--MAX_DIV	<= b"000" & c_MAX_DIV(31 downto 3);	
			MAX_DIV	<=  x"00000000" + SYSCLK / 8000 - 1;	-- 1000
		end if;
		
		-- catch turbo mode change
		if turbo_old /= turbo then
			turbo_old <= turbo;
			clockDiv <= x"00000000";
		end if;
	end process;

	-- keycode auf den ausgang schieben
	shiftout : process
	begin
		wait until rising_edge(clk);

		if (keyClockEn) then
			if (pulseCnt > 0) then
				pulseCnt <= pulseCnt - 1;
				remo <= '0';
			elsif (keyShift /= "00000000") then
				if (keyShift = "00000001") then -- letztes bit
						pulseCnt <= 13; -- -> Wortabstand
					elsif (keyShift(0)='1') then
						pulseCnt <= 6; -- 1 Bit
					else
						pulseCnt <= 4; -- 0 Bit
				end if;
				keyShift <= '0' & keyShift(7 downto 1);
				remo <= '1';
			elsif (keyRepeat > 0) then
				keyRepeat <= keyRepeat - 1;
				keyShift <= currentKey;
			-- in turbo mode single key press only
			elsif (key_cnt_old /= key_cnt) or (key_repeat_state = '1' and turbo = b"00") then
				key_cnt_old <= key_cnt;
				keyRepeat  <= 0;
				keyShift   <= '1' & key(6 downto 0);
				currentKey <= '1' & key(6 downto 0);
			end if;
		end if;
		
		-- fresh key is pressed
		if keydownDelayed = true then
			key <= std_logic_vector(to_unsigned(iKey,8));
			currentKey <= '1' & std_logic_vector(to_unsigned(iKey,7));
			key_cnt <= key_cnt + 1;
			key_repeat_state <= '1';
			keyRepeat  <= 1;
			key_repeat_cnt   <= x"00380000";
		end if;
		
		-- key is released
		if keyupDelayed = true then
			key_repeat_state <= '0';
		end if;
	end process;
end;