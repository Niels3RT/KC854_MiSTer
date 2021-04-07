library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity modules is
	generic (
        NUMINTS : integer := 8
	);
	port (
		cpuclk			: in  std_logic;
		cpuEn				: in  std_logic;
		cpuReset_n		: in  std_logic;

		ioSel				: in  boolean;

		addr				: in  std_logic_vector(15 downto 0);
		dIn				: in  std_logic_vector(7 downto 0);
		dOut				: out std_logic_vector(7 downto 0);
		m1_n				: in  std_logic;
		mreq_n			: in  std_logic;
		iorq_n			: in  std_logic;
		rd_n				: in  std_logic;
		wr_n				: in  std_logic;
		
		int				: out std_logic_vector(NUMINTS-1 downto 6);
		intAck			: in  std_logic_vector(NUMINTS-1 downto 0);

		modcs_n			: out std_logic;
		
		bi_n				: in  std_logic;
		joystick_0		: in  std_logic_vector(31 downto 0);
		
		ioctl_download	: in  std_logic;
		ioctl_index		: in  std_logic_vector(7 downto 0);
		ioctl_wr			: in  std_logic;
		ioctl_addr		: in  std_logic_vector(24 downto 0);
		ioctl_data		: in  std_logic_vector(7 downto 0)
	);
	end modules;

architecture rtl of modules is
	-- m003, 2x uart
	signal m003Slot		: std_logic_vector(7 downto 0);
	signal m003DataOut	: std_logic_vector(7 downto 0);
	signal m003cs			: std_logic;
	signal m003RXDa		: std_logic;
	signal m003TXDa		: std_logic;
	signal m003RXDb		: std_logic;
	signal m003TXDb		: std_logic;
	signal m003Test		: std_logic_vector(7 downto 0);

	-- m008, joystick
	signal m008DataOut	: std_logic_vector(7 downto 0);
	signal m008CS_n		: std_logic;
	
	-- m025, software
	signal m025Slot		: std_logic_vector(7 downto 0);
	signal m025DataOut	: std_logic_vector(7 downto 0);
	signal m025CS_n		: std_logic;
	
	-- other signals
	signal LEDR				: std_logic_vector(15 downto 0) := (others => '0');
	signal SW				: std_logic_vector(9 downto 0) := (others => '0');
begin
	-- assign slots
	m003Slot <= x"08";
	m025Slot <= x"0c";

	-- external mod select
	modcs_n <= 
		'0'	when m003cs		= '1' else
		'0'	when m008CS_n	= '0' else
		'0'	when m025CS_n	= '0' else
		'1';
		
	-- modules data out
	dOut <= 
		m003DataOut	when m003cs   = '1'	or intAck(15 downto 6)  /= "0000000000" else
		m008DataOut	when m008CS_n = '0'	or intAck(17 downto 16) /= "00"   else
		m025DataOut	when m025CS_n = '0' else
		x"ff";
	
	-- M008/Joystick PIO: 90H-97BH reserved for M008, here only 90h is used
	m008CS_n <= '0' when addr(7 downto 2) = "100100" and ioSel else '1';
	
	----------   M003, 2x uart   ----------------------------
	m003 : entity work.m003
		port map (
			clk      => cpuclk,
			sysClkEn => cpuEn,
			res_n    => cpuReset_n,
			
			ioSel    => ioSel,
			slot     => m003Slot,

			addr     => addr,
			dIn      => dIn,
			dOut     => m003DataOut,

			modSel   => m003cs,
			modEna   => LEDR(9),

			m1_n     => m1_n,
			mreq_n   => mreq_n,
			iorq_n   => iorq_n,
			rd_n     => rd_n,
			wr_n     => wr_n,

			int      => int(15 downto 6),
			intAck   => intAck(15 downto 6),

			divideBy2 => SW(2),
			aRxd     => m003RXDa,
			aTxd     => m003TXDa,
			bRxd     => m003RXDb,
			bTxd     => m003TXDb,

			test     => m003Test
		);
		
	----------   M008, joystick   ----------------------------	
	pio_M008 : entity work.pio
		port map (
			clk     => cpuclk,
			res_n   => cpuReset_n,
			
			dIn     => dIn,
			dOut    => m008DataOut,
			baSel   => addr(0),
			cdSel   => addr(1),
			cs_n    => m008CS_n,
			m1_n    => m1_n and cpuReset_n,
			iorq_n  => iorq_n,
			rd_n    => rd_n,
			wr_n    => wr_n,
			intAck  => intAck(17 downto 16),
			int     => int(17 downto 16),
			-- fire, fire2, right, left, down, up
			aIn     => b"11" & not joystick_0(4) & not joystick_0(5) & not joystick_0(0) & not joystick_0(1) & not joystick_0(2) & not joystick_0(3),
			aOut    => open,
			aRdy    => open,
			aStb    => bi_n,
			bIn     => x"ff",
			bOut    => open,
			bRdy    => open,
			bStb    => bi_n
		);
	
	----------   M025, software   ----------------------------
	m025 : entity work.m025
		port map (
			clk      => cpuclk,
			cpuEn    => cpuEn,
			res_n    => cpuReset_n,
			
			ioSel    => ioSel,
			slot     => m025Slot,
			modcs_n  => m025CS_n,

			addr     => addr,
			dIn      => dIn,
			dOut     => m025DataOut,

			m1_n     => m1_n and cpuReset_n,
			mreq_n   => mreq_n,
			iorq_n   => iorq_n,
			rd_n     => rd_n,
			wr_n     => wr_n,
			
			ioctl_download => ioctl_download,
			ioctl_index => ioctl_index,
			ioctl_wr    => ioctl_wr,
			ioctl_addr  => ioctl_addr,
			ioctl_data  => ioctl_data
		);
end;
