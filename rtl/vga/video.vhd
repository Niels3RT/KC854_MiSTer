--
-- 2021, Niels Lueddecke
--
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

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity video is
	port (
		clk_sys			: in  std_logic;
		tick_vid			: in  std_logic;

		ce_pix			: out std_logic;

		vgaRed			: out std_logic_vector(7 downto 0);
		vgaGreen			: out std_logic_vector(7 downto 0);
		vgaBlue			: out std_logic_vector(7 downto 0);
		vgaHSync			: out std_logic;
		vgaVSync			: out std_logic;
		vgaHBlank		: out std_logic;
		vgaVBlank		: out std_logic;
		
		zi_n				: out std_logic;
		bi_n				: out std_logic;
		h4					: out std_logic;

		irm_adr			: out std_logic_vector(13 downto 0);
		irmPb0_do_2		: in  std_logic_vector(7 downto 0);
		irmCb0_do_2		: in  std_logic_vector(7 downto 0);
		irmPb1_do_2		: in  std_logic_vector(7 downto 0);
		irmCb1_do_2		: in  std_logic_vector(7 downto 0);
		
		set_img			: in  std_logic;
		set_cmode		: in  std_logic;
		set_blinken		: in  std_logic;
		blink				: in  std_logic
	);
end video;

architecture rtl of video is
	-- vid constants
	constant H_SYNC_ACTIVE	: std_logic := '1';
	constant H_BLANK_ACTIVE	: std_logic := '1';
	constant V_SYNC_ACTIVE	: std_logic := '1';
	constant V_BLANK_ACTIVE	: std_logic := '1';

	-- pipeline register
	type reg is record
		do_stuff				: std_logic;
		cnt_h					: unsigned(11 downto 0);
		cnt_v					: unsigned(11 downto 0);
		pos_x					: unsigned(11 downto 0);
		pos_y					: unsigned(11 downto 0);
		sync_h				: std_logic;
		sync_v				: std_logic;
		blank_h				: std_logic;
		blank_v				: std_logic;
		color					: std_logic_vector(5 downto 0);
		draw_pixel			: std_logic;
		col_blink			: std_logic;
		byte_pixel			: std_logic_vector(7 downto 0);
		byte_color			: std_logic_vector(7 downto 0);
	end record;

	signal s0 : reg := ('0', (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), '0', '0', '0', '0', (others=>'0'), '0', '0', (others=>'0'), (others=>'0'));
	signal s1 : reg := ('0', (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), '0', '0', '0', '0', (others=>'0'), '0', '0', (others=>'0'), (others=>'0'));
	signal s2 : reg := ('0', (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), '0', '0', '0', '0', (others=>'0'), '0', '0', (others=>'0'), (others=>'0'));
	signal s3 : reg := ('0', (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), '0', '0', '0', '0', (others=>'0'), '0', '0', (others=>'0'), (others=>'0'));
	signal s4 : reg := ('0', (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), '0', '0', '0', '0', (others=>'0'), '0', '0', (others=>'0'), (others=>'0'));
	signal s5 : reg := ('0', (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), '0', '0', '0', '0', (others=>'0'), '0', '0', (others=>'0'), (others=>'0'));

	-- counter
	signal cnt_h			: unsigned(11 downto 0) := (others => '0');
	signal cnt_v			: unsigned(11 downto 0) := (others => '0');
	signal cnt_h4			: unsigned(7 downto 0) := (others => '0');
	
	-- blink
	signal blink_old		: std_logic;
	signal do_blink		: std_logic;

begin
	vid_gen : process 
	begin
		wait until rising_edge(clk_sys);
		
		-- detect blink edge
		blink_old <= blink;
		if blink_old /= blink and blink = '0' then
			do_blink <= not do_blink;
		end if;
		
		-- defaults
		s0.do_stuff   <= '0';
		
		-- tick vid
		if tick_vid = '1' then
			-- h4 counter
			cnt_h4 <= cnt_h4 + 1;
			h4     <= cnt_h4(7);
			-- hsync counter
			if cnt_h < 452 then
				cnt_h <= cnt_h + 1;
				-- reset h4
				if cnt_h = 96 - 9 then		-- 1,21 us
					cnt_h4 <= x"00";
				end if;
			else
				cnt_h <= x"000";
				-- vsync counter
				if cnt_v < 312 then
					cnt_v <= cnt_v + 1;
				else
					cnt_v <= x"000";
				end if;
			end if;
			-- fill pipeline
			s0.do_stuff <= '1';
			s0.cnt_h    <= cnt_h;
			s0.cnt_v    <= cnt_v;
			s0.sync_h   <= not H_SYNC_ACTIVE;
			s0.sync_v   <= not V_SYNC_ACTIVE;
			s0.blank_h  <= H_BLANK_ACTIVE;
			s0.blank_v  <= V_BLANK_ACTIVE;
		end if;
		
		-- work the pipe
		-- stage 0
		s1 <= s0;
		if s0.do_stuff = '1' then
			s1.pos_x <= s0.cnt_h - 96; -- ok
			s1.pos_y <= s0.cnt_v - 6;
			-- horizontal sync
			if s0.cnt_h < 40 then		-- B&O syncs ok
				s1.sync_h <= H_SYNC_ACTIVE;
			end if;
			-- vertical sync
			if s0.cnt_v > 280 and s0.cnt_v < 284 then		-- seems ok? B&O seems to like it
				s1.sync_v <= V_SYNC_ACTIVE;
			end if;
		end if;
		-- stage 1
		s2 <= s1;
		if s1.do_stuff = '1' then
			-- blank signals
			if s1.pos_x < 320 then
				s2.blank_h <= not H_BLANK_ACTIVE;
			end if;
			if s1.pos_y < 256 then
				s2.blank_v <= not V_BLANK_ACTIVE;
			end if;
			-- set video ram address
			irm_adr <= std_logic_vector(s1.pos_x(8 downto 3) & s1.pos_y(7 downto 0));
		end if;
		-- stage 2
		s3 <= s2;
		-- stage 3
		s4 <= s3;
		if s3.do_stuff = '1' then
			-- display image 0
			if set_img = '0' then
				s4.byte_pixel <= irmPb0_do_2;
				s4.byte_color <= irmCb0_do_2;
			else
			-- display image 1
				s4.byte_pixel <= irmPb1_do_2;
				s4.byte_color <= irmCb1_do_2;
			end if;
		end if;
		-- stage 3
		s5 <= s4;
		if s4.do_stuff = '1' then
			-- normal color mode
			if set_cmode = '1' then
				-- get color data
				case s4.byte_color(6 downto 3) is
					when "0001" => s5.color <= "000011"; -- blau
					when "0010" => s5.color <= "110000"; -- rot
					when "0011" => s5.color <= "110011"; -- purpur
					when "0100" => s5.color <= "001100"; -- gruen
					when "0101" => s5.color <= "001111"; -- tuerkis
					when "0110" => s5.color <= "111100"; -- gelb
					when "0111" => s5.color <= "111111"; -- weiss
					when "1001" => s5.color <= "100011"; -- violett
					when "1010" => s5.color <= "111000"; -- orange
					when "1011" => s5.color <= "110010"; -- purpurrot
					when "1100" => s5.color <= "001110"; -- gruenblau
					when "1101" => s5.color <= "001011"; -- blaugruen
					when "1110" => s5.color <= "101100"; -- gelbgruen
					when "1111" => s5.color <= "111111"; -- weiss
					when others => s5.color <= "000000"; -- schwarz
				end case;
				s5.col_blink <= s4.byte_color(7);
				-- draw pixel?
				if		s4.pos_x(2 downto 0) = b"111" and s4.byte_pixel(0) = '1' then s5.draw_pixel <= '1';
				elsif	s4.pos_x(2 downto 0) = b"110" and s4.byte_pixel(1) = '1' then s5.draw_pixel <= '1';
				elsif	s4.pos_x(2 downto 0) = b"101" and s4.byte_pixel(2) = '1' then s5.draw_pixel <= '1';
				elsif	s4.pos_x(2 downto 0) = b"100" and s4.byte_pixel(3) = '1' then s5.draw_pixel <= '1';
				elsif	s4.pos_x(2 downto 0) = b"011" and s4.byte_pixel(4) = '1' then s5.draw_pixel <= '1';
				elsif	s4.pos_x(2 downto 0) = b"010" and s4.byte_pixel(5) = '1' then s5.draw_pixel <= '1';
				elsif	s4.pos_x(2 downto 0) = b"001" and s4.byte_pixel(6) = '1' then s5.draw_pixel <= '1';
				elsif	s4.pos_x(2 downto 0) = b"000" and s4.byte_pixel(7) = '1' then s5.draw_pixel <= '1';
				else
					s5.draw_pixel <= '0';
				end if;
			-- hires color mode
			else
				if		s4.pos_x(2 downto 0) = b"111" then s5.color(1) <= s4.byte_color(0); s5.color(0) <= s4.byte_pixel(0);
				elsif	s4.pos_x(2 downto 0) = b"110" then s5.color(1) <= s4.byte_color(1); s5.color(0) <= s4.byte_pixel(1);
				elsif	s4.pos_x(2 downto 0) = b"101" then s5.color(1) <= s4.byte_color(2); s5.color(0) <= s4.byte_pixel(2);
				elsif	s4.pos_x(2 downto 0) = b"100" then s5.color(1) <= s4.byte_color(3); s5.color(0) <= s4.byte_pixel(3);
				elsif	s4.pos_x(2 downto 0) = b"011" then s5.color(1) <= s4.byte_color(4); s5.color(0) <= s4.byte_pixel(4);
				elsif	s4.pos_x(2 downto 0) = b"010" then s5.color(1) <= s4.byte_color(5); s5.color(0) <= s4.byte_pixel(5);
				elsif	s4.pos_x(2 downto 0) = b"001" then s5.color(1) <= s4.byte_color(6); s5.color(0) <= s4.byte_pixel(6);
				elsif	s4.pos_x(2 downto 0) = b"000" then s5.color(1) <= s4.byte_color(7); s5.color(0) <= s4.byte_pixel(7);
				else
					s5.draw_pixel <= '0';
				end if;
			end if;
		end if;
		-- stage 5
		-- output signals
		if s5.do_stuff = '1' then
			if s5.blank_h /= H_BLANK_ACTIVE and s5.blank_v /= V_BLANK_ACTIVE then
				-- normal color mode
				if set_cmode = '1' then
					if s5.draw_pixel = '1' and not (set_blinken = '1' and s5.col_blink = '1' and do_blink = '1')  then
						-- draw pixel
						vgaRed   <= s5.color(5 downto 4) & s5.color(4) & s5.color(4) & x"0";
						vgaGreen <= s5.color(3 downto 2) & s5.color(2) & s5.color(2) & x"0";
						vgaBlue  <= s5.color(1 downto 0) & s5.color(0) & s5.color(0) & x"0";
					else
						-- background color
						vgaRed   <= s5.byte_color(1) & b"0000000";
						vgaGreen <= s5.byte_color(2) & b"0000000";
						vgaBlue  <= s5.byte_color(0) & b"0000000";
					end if;
				-- hires color mode
				else
					vgaRed   <= s5.color(0) & s5.color(0) & s5.color(0) & s5.color(0) & x"0";
					vgaGreen <= s5.color(1) & s5.color(1) & s5.color(1) & s5.color(1) & x"0";
					vgaBlue  <= s5.color(1) & s5.color(1) & s5.color(1) & s5.color(1) & x"0";
				end if;
			else	-- show black outside video area, B&O likes it
				vgaRed   <= x"00";
				vgaGreen <= x"00";
				vgaBlue  <= x"00";
			end if;
			vgaHSync  <= s5.sync_h;
			vgaVSync  <= s5.sync_v;
			vgaHBlank <= s5.blank_h;
			vgaVBlank <= s5.blank_v;
			zi_n      <= s5.blank_h;
			bi_n      <= s5.blank_v;
		end if;
		-- turn on/off video output
		ce_pix <= s5.do_stuff;
	end process;
end;
