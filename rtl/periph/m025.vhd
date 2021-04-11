library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity m025 is
    generic (
		  STRUKTURBYTE :  std_logic_vector(7 downto 0) := x"fb"		-- m012 texor
    );
    port (
		clk				: in  std_logic;
		cpuEn				: in  std_logic;
		res_n				: in  std_logic;
		
		ioSel				: in  boolean;
		slot				: in  std_logic_vector(7 downto 0);
		modcs_n			: out std_logic;

		addr				: in  std_logic_vector(15 downto 0);
		dIn				: in  std_logic_vector(7 downto 0);
		dOut				: out std_logic_vector(7 downto 0);

		m1_n				: in  std_logic;
		mreq_n			: in  std_logic;
		iorq_n			: in  std_logic;
		rd_n				: in  std_logic;
		wr_n				: in  std_logic;
		
		ioctl_download	: in  std_logic;
		ioctl_index		: in  std_logic_vector(7 downto 0);
		ioctl_wr			: in  std_logic;
		ioctl_addr		: in  std_logic_vector(24 downto 0);
		ioctl_data		: in  std_logic_vector(7 downto 0)
    );
end m025;

architecture rtl of m025 is
	signal rom_adr			: std_logic_vector(12 downto 0);
	signal rom_data_out	: std_logic_vector(7 downto 0);
	signal rom_we_n		: std_logic;
	
	signal is_enabled		: std_logic := '0';
	signal base_adr		: std_logic_vector(2 downto 0);

begin
	-- data out
	dOut <=
		STRUKTURBYTE	when ioSel and addr = slot & x"80"	else
		rom_data_out	when mreq_n = '0' and rd_n = '0'		else
		x"ff";
	
	-- module select
	modcs_n <=	'0' when addr(15 downto 0)  = slot & x"80" and ioSel else
					'0' when addr(15 downto 13) = base_adr and mreq_n = '0' and rd_n = '0' and is_enabled = '1' else
					'1';
					
	-- write enable for rom loading
	rom_we_n <=	'0' when ioctl_download = '1' and ioctl_index = x"05" else
					'1';
	
	-- switch rom addr between loading and reading
	rom_adr <=	ioctl_addr(12 downto 0) when rom_we_n = '0' else
					addr(12 downto 0);
	
	-- handle stuff process
	process (clk)
	begin
		if rising_edge(clk) then
		
			-- get steuerbyte
			if (addr = slot & x"80") and ioSel and wr_n = '0' then
				is_enabled <= dIn(0);
				base_adr   <= dIn(7 downto 5);
			end if;
			
		end if;
	end process;
	
	-- rom, 8kb
	sram_rom : entity work.sram
		generic map (
			AddrWidth => 13,
			DataWidth => 8
		)
		port map (
			clk  => clk,
			addr => rom_adr,
			din  => ioctl_data,
			dout => rom_data_out,
			ce_n => '0', 
			we_n => rom_we_n
		);
end;
