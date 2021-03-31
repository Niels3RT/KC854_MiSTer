--
-- turbo things added by Niels Lueddecke in 2021
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
-- Erzeugung der Takte fuer KC
--   CPU+CTC
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity sysclock is
	port (
		clk			: in  std_logic;
		cpuEn			: in  std_logic;

		turbo			: in  std_logic_vector(1 downto 0);
		
		tick_cpu		: out std_logic;	-- 1,7734475 MHz (clk_sys / 32)
		tick_vid		: out std_logic	-- 7,09379 MHz (clk_sys / 8)
	);
end sysclock;

architecture rtl of sysclock is
	signal cnt_cpu				: unsigned(7 downto 0) := (others => '0');
	signal cnt_vid				: unsigned(3 downto 0) := (others => '0');
	--signal cpuEn_shift		: std_logic_vector(7 downto 0) := (others => '0');
	signal turbo_use			: std_logic_vector(1 downto 0);

 
begin
	cpuClk : process 
	begin
		wait until rising_edge(clk);
		
		tick_cpu	   <= '0';
		--cpuEn_shift <= cpuEn_shift(6 downto 0) & cpuEn;
		
		-- tick cpu, wait some clocks on max setting
		if	turbo_use = b"11" then
			--if cpuEn_shift(3) = '1' then	-- ok
			--if cpuEn_shift(2) = '1' then	-- ok
			--if cpuEn_shift(1) = '1' then	-- ok
			--if cpuEn_shift(0) = '1' then	-- ok
			if cpuEn = '1' then	-- ok
				tick_cpu	 <= '1';
				turbo_use <= turbo;
			end if;
		-- tick cpu, use counter for the more normal settings
		else
			if (cnt_cpu > 0) then
				cnt_cpu	<= cnt_cpu - 1;
			else
				-- turbo setting
				if		turbo = b"00" then
					cnt_cpu	<= b"00011111";	-- 1x, /32
				elsif	turbo = b"01" then
					cnt_cpu	<= b"00001111";	-- 2x, /16
				elsif	turbo = b"10" then
					cnt_cpu	<= b"00000111";	-- 4x, /8
				end if;
				tick_cpu	 <= '1';
				turbo_use <= turbo;
			end if;
		end if;
		
		-- tick vid
		if (cnt_vid > 0) then
			cnt_vid	<= cnt_vid - 1;
			tick_vid	<= '0';
		else
			cnt_vid	<= x"7";
			tick_vid	<= '1';
		end if;
	end process;    
end;

