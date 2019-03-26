library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.std_logic_arith.all;

entity part1 is
   port (
		-- clock availble
		clock_50			: 	in    std_logic;
		clock_27			:	in 	bit_vector (0 to 1);
		clock_24			:	in 	bit_vector (0 to 1);
		
		-- audio control interface
		i2c_sdat			: 	inout std_logic;
		i2c_sclk			: 	out   std_logic;
		aud_xck 			:	out   std_logic;
		
		-- digital audio interface
		aud_daclrck   	: 	in    std_logic;
      aud_adclrck		: 	in    std_logic;
		aud_bclk			: 	in    std_logic;
		aud_adcdat 		:	in    std_logic;
		aud_dacdat		: 	out   std_logic;
		
		--comunication
		gpio_0		:	in bit_vector (0 to 39);
		gpio_1		:	out bit_vector (0 to 39);
		
		--memory
		sram_addr	:	out 	std_logic_vector (17 downto 0);
		sram_dq		:	inout std_logic_vector (15 downto 0);
		sram_we_n	:	out	bit;
		sram_oe_n	:	out	bit;
		sram_ub_n	:	out 	bit;
		sram_lb_n	:	out	bit;
		sram_ce_n	:	out	bit;
		
		--interface
		hex3	:	out		bit_vector 	(0 to 6);
		hex2	:	out		bit_vector 	(0 to 6);
		hex1	:	out		bit_vector 	(0 to 6);
		hex0	:	out		bit_vector 	(0 to 6);
		--ledg	: 	buffer 	bit_vector 	(0 to 7);
		ledg	: 	buffer 	std_logic_vector	(7 downto 0);
		ledr	: 	buffer 	std_logic_vector 	(9 downto 0);
		sw		:	in			bit_vector	(9 downto 0);
		key	:	in			bit_vector	(0 to 3)

      
	);
end part1;

architecture behavior of part1 is
	-- code customization init
	component bluetooth_module
		port(
			bluetoothData 		:	inout 	std_logic_vector(7 downto 0);
			writedata_left,
			writedata_right	: 	in 		std_logic_vector(23 downto 0);
			read_s, 
			write_s 				: 	in			std_logic;
			clock_24				:	in			bit_vector (0 to 1);
			gpio_0				:	in			bit_vector (0 to 39)--;
			--ledg 					:	out		std_logic_vector (7 downto 0)
		);
	end component;
	
	component SRAM
		port(
			bluetoothData 		:	inout 	std_logic_vector(7 downto 0);
			writedata_left,
			writedata_right	: 	inout 	std_logic_vector(23 downto 0);
			readdata_left,
			readdata_right 	: 	in 		std_logic_vector(23 downto 0);
			read_s, 
			write_s 				: 	in			std_logic;
			ledr					: 	buffer	std_logic_vector 	(9 downto 0);
			ledg					: 	buffer 	std_logic_vector 	(7 downto 0);
			clock_50				:	in 		std_logic;
			clock_27				:	in 		bit_vector (0 to 1);
			clock_24				:	in 		bit_vector (0 to 1);
			sram_addr			:	out 		std_logic_vector (17 downto 0);
			sram_dq				:	inout 	std_logic_vector (15 downto 0);
			sram_we_n			:	out		bit;
			sram_oe_n			:	out		bit;
			sram_ub_n			:	out 		bit;
			sram_lb_n			:	out		bit;
			sram_ce_n			:	out		bit;			
			aud_daclrck   		: 	in    	std_logic;
			aud_adclrck			: 	in    	std_logic;
			key					:	in			bit_vector (0 to 3);
			sw						:	in			bit_vector (9 downto 0);
			hex3					:	out		bit_vector (0 to 6);
			hex2					:	out		bit_vector (0 to 6);
			hex1					:	out		bit_vector (0 to 6);
			hex0					:	out		bit_vector (0 to 6)
		);
	end component;
	-- code customization end
	
   component clock_generator
      port( 
			clock_27 : in std_logic;
         reset    : in std_logic;
         aud_xck  : out std_logic
		);
   end component;

   component audio_and_video_config
      port( 
			clock_50, 
			reset 			: in    std_logic;
         i2c_sdat       : inout std_logic;
         i2c_sclk       : out   std_logic
		);
   end component;   

   component audio_codec
      port( 
			clock_50, 
			reset, 
			read_s, 
			write_s         	: in  std_logic;
         
			writedata_left, 
			writedata_right 	: in  std_logic_vector(23 downto 0);
			
         aud_adcdat, 
			aud_bclk, 
			aud_adclrck, 
			aud_daclrck 		: in  std_logic;
			
         read_ready, 
			write_ready			: out std_logic;
         
			readdata_left, 
			readdata_right    : out std_logic_vector(23 downto 0);
			
         aud_dacdat        : out std_logic
		);
   end component;

	signal bluetoothData	:	std_logic_vector(7 downto 0);
	
   signal 
		clock2_50, 
		read_ready, 
		write_ready, 
		read_s, 
		write_s 				: std_logic;
		
   signal 
		readdata_left, 
		readdata_right    : std_logic_vector(23 downto 0);
		
   signal 
		writedata_left, 
		writedata_right   : std_logic_vector(23 downto 0);   
		
   signal reset         : std_logic;
begin
   --reset <= not(to_stdulogic(key(0)));
	reset <= '0';
	clock2_50 <= clock_50;
   --your code goes here
   --writedata_left <= readdata_left when key(1)='0' else readdata_right ;
   --writedata_right <= readdata_right when key(1)='0' else "000000000000000000000000";	
   read_s <= read_ready;
   write_s <= write_ready and read_ready;
		
	gpio_1(0) <= to_bit(write_s);
	gpio_1(1) <= to_bit(read_s);
	
	my_clock_gen: clock_generator 
	port map (
		clock2_50, 
		reset, 
		aud_xck
	);
	
   cfg: audio_and_video_config 
	port map (
		clock_50, 
		reset, 
		i2c_sdat, 
		i2c_sclk
	);
	
   codec: audio_codec 
	port map (
		clock_50, 
		reset, 
		read_s, 
		write_s, 
		writedata_left, 
		writedata_right, 
		aud_adcdat, 
		aud_bclk, 
		aud_adclrck,
		aud_daclrck, 
		read_ready, 
		write_ready, 
		readdata_left, 
		readdata_right, 
		aud_dacdat
	);
	
	-- customization init
	bluetooth : bluetooth_module 
	port map(
		bluetoothData		=> bluetoothData,
		writedata_left 	=> writedata_left,
		writedata_right	=> writedata_right,
		read_s				=>	read_s, 
		write_s 				=> write_s,
		clock_24 			=> clock_24,
		gpio_0				=>	gpio_0--,
		--ledg					=> ledg
	);
		
	memory	:	SRAM 
	port map(
		bluetoothData		=> bluetoothData,
		writedata_left 	=> writedata_left,
		writedata_right	=> writedata_right,
		readdata_left		=> readdata_left,
		readdata_right 	=> readdata_right,
		read_s				=>	read_s, 
		write_s				=>	write_s, 
		ledr					=>	ledr,
		ledg					=>	ledg,
		clock_50				=> clock_50,
		clock_27				=> clock_27,
		clock_24				=> clock_24,
		sram_addr 			=> sram_addr,
		sram_dq 				=> sram_dq,
		sram_we_n			=> sram_we_n,
		sram_oe_n 			=> sram_oe_n,
		sram_ub_n 			=> sram_ub_n,
		sram_lb_n			=> sram_lb_n,
		sram_ce_n			=> sram_ce_n,
		aud_daclrck 		=> aud_daclrck,
		aud_adclrck			=> aud_adclrck,
		key					=> key,
		sw						=> sw,
		hex3					=> hex3,
		hex2					=> hex2,
		hex1					=> hex1,
		hex0					=> hex0
	);
	-- customization end


end behavior;
