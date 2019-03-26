-- projeto_base -> memory_SRAM
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;
use ieee.Std_Logic_Unsigned.all;

entity SRAM is
	port(	
		-- custom port
		bluetoothData 		:	inout 	std_logic_vector(7 downto 0);
		
		-- audio
		writedata_left,
		writedata_right	: 	inout 	std_logic_vector(23 downto 0);
		readdata_left,
		readdata_right 	: 	in 		std_logic_vector(23 downto 0);
		read_s, 
		write_s 				: 	in			std_logic;
		ledr					: 	buffer 	std_logic_vector 	(9 downto 0);
		ledg					: 	buffer 	std_logic_vector 	(7 downto 0);
		
		-- clock availble
		clock_50				:	in 		std_logic;
		clock_27				:	in 		bit_vector (0 to 1);
		clock_24				:	in 		bit_vector (0 to 1);
		
		--memory
		sram_addr			:	out 		std_logic_vector (17 downto 0);
		sram_dq				:	inout 	std_logic_vector (15 downto 0);
		sram_we_n			:	out		bit;
		sram_oe_n			:	out		bit;
		sram_ub_n			:	out 		bit;
		sram_lb_n			:	out		bit;
		sram_ce_n			:	out		bit;
		
		-- Audio Moment
		aud_daclrck   		: 	in   	 	std_logic;
		aud_adclrck			: 	in    	std_logic;
		
		--interface
		key					:	in			bit_vector (0 to 3);
		sw						:	in			bit_vector (9 downto 0);
		hex3					:	out		bit_vector (0 to 6);
		hex2					:	out		bit_vector (0 to 6);
		hex1					:	out		bit_vector (0 to 6);
		hex0					:	out		bit_vector (0 to 6)
	);
end SRAM;

architecture Memory_SRAM of SRAM is
	-- memory addressing
	signal	addressing17Bits	:	std_logic_vector	(17 downto 0) := "000000000000000000";
	signal	addressing17Max	:	std_logic_vector	(17 downto 0) := "111111111111111111";
	constant	oneBit				:	std_logic_vector	(17 downto 0) := "000000000000000001";
	constant	addressingStart	:	std_logic_vector	(17 downto 0) := "000000000000000000";
	
	-- memory data
	constant ioLocker				:	std_logic_vector	(15 downto 0) := "ZZZZZZZZZZZZZZZZ";
	
	-- memory controller
	signal	writeEnable			:	bit := '1';
	signal	readEnable			:	bit := '1';
	
	--memory Operation
	signal	mode					:	integer range 0 to 7 := 0;
	signal	readyStats			:	bit := '0';
	constant memRec				:	integer := 0;
	constant memRec1				:	integer := 1;
	constant memRead				:	integer := 2;
	constant memRead1				:	integer := 3;
	constant memNULL				:	integer := 4;
	constant memNULL1				:	integer := 5;
	
	type decimal is array (0 to 15) of bit_vector (0 to 6);
	constant b2h : decimal := (
		0 =>  "0000001",
		1 =>  "1001111",
		2 =>  "0010010",
		3 =>  "0000110",
		4 =>  "1001100",		
		5 =>  "0100100",		
		6 =>  "0100000",		
		7 =>  "0001101",
		8 =>  "0000000",
		9 =>  "0000100",
		10=>  "0001000",
		11=>  "1100000",
		12=>  "0110001",
		13=>  "1000010",
		14=>  "0110000",
		15=>  "0111000"
	);

	signal soundBuffer		:	std_logic_vector (23 downto 0);
	
	constant maxSRAM			:	integer := 567; -- 'magic' number do not change i'm joking this is 50 mHz / 88.2048 kHz 567
	signal stateSRAM			:	integer range 0 to maxSRAM:=0;

	constant clockCounter	:	integer := 135;
	signal clockReducer		:	integer range 0 to clockCounter:=0;
	signal clockSignal		:	bit := '0';
	
	signal appMode				:	integer range 0 to 7 := 0;
	signal appSRA				:	integer range 1 to 4 := 1;
	
	
	begin
		-- display the address
		hex3 <= b2h(to_integer(ieee.numeric_std.unsigned(addressing17Bits(15 downto 12))));
		hex2 <= b2h(to_integer(ieee.numeric_std.unsigned(addressing17Bits(11 downto  9))));
		hex1 <= b2h(to_integer(ieee.numeric_std.unsigned(bluetoothData( 7 downto  4))));
		hex0 <= b2h(to_integer(ieee.numeric_std.unsigned(bluetoothData( 3 downto  0))));
		-- hex1 <= b2h(to_integer(ieee.numeric_std.unsigned(addressing17Bits( 9 downto  6))));
		-- hex0 <= b2h(to_integer(ieee.numeric_std.unsigned(addressing17Bits( 5 downto  2))));
		sram_addr <= addressing17Bits;
		--ledg <= bluetoothData;
		
		-- memory
		sram_ub_n <= '0';
		sram_lb_n <= '0';
		sram_ce_n <= '0';
		writedata_left 	<= (to_stdlogicvector((to_bitvector(soundBuffer) sra appSRA)) 	+ to_stdlogicvector(to_bitvector(readdata_left)  sra 1));
		writedata_right 	<= (to_stdlogicvector((to_bitvector(soundBuffer) sra appSRA))	+ to_stdlogicvector(to_bitVector(readdata_right) sra 1));
		
		-- clock reducer;
		reduce_clock:process (clock_50)
			begin
				-- ===================================
				-- Bluetooth Setup App Interface
				-- ===================================
				-- Echo (in decimal is 111 to 148)
				-- ===================================
				if (	bluetoothData = x"6F" or bluetoothData = x"FF"	)then
					addressing17Max <= "001100011001111111";--1
					appMode <= 1;
				elsif bluetoothData = x"70" then
					addressing17Max <= "001100111010111011";--2
					appSRA <= 1;
				elsif bluetoothData = x"71" then
					addressing17Max <= "001101011011110001";--3
					appSRA <= 1;
				elsif bluetoothData = x"72" then
					addressing17Max <= "001101111100100111";--4
					appSRA <= 1;
				elsif bluetoothData = x"73" then
					addressing17Max <= "001110011101011101";--5
					appSRA <= 1;
				elsif bluetoothData = x"74" then
					addressing17Max <= "001110111110010011";--6
					appSRA <= 1;
				elsif bluetoothData = x"75" then
					addressing17Max <= "001111011111001001";--7
					appSRA <= 1;
				elsif bluetoothData = x"76" then
					addressing17Max <= "001111111111111111";--8
					appSRA <= 1;
				
				elsif bluetoothData = x"79" then
					addressing17Max <= "001100011001111111";--1
					appSRA <= 2;
				elsif bluetoothData = x"7A" then
					addressing17Max <= "001100111010111011";--2
					appSRA <= 2;
				elsif bluetoothData = x"7B" then
					addressing17Max <= "001101011011110001";--3
					appSRA <= 2;
				elsif bluetoothData = x"7C" then
					addressing17Max <= "001101111100100111";--4
					appSRA <= 2;
				elsif bluetoothData = x"7D" then
					addressing17Max <= "001110011101011101";--5
					appSRA <= 2;
				elsif bluetoothData = x"7E" then
					addressing17Max <= "001110111110010011";--6
					appSRA <= 2;
				elsif bluetoothData = x"7F" then
					addressing17Max <= "001111011111001001";--7
					appSRA <= 2;
				elsif bluetoothData = x"80" then
					addressing17Max <= "001111111111111111";--8
					appSRA <= 2;
				
				elsif bluetoothData = x"83" then
					addressing17Max <= "001100011001111111";--1
					appSRA <= 3;
				elsif bluetoothData = x"84" then
					addressing17Max <= "001100111010111011";--2
					appSRA <= 3;
				elsif bluetoothData = x"85" then
					addressing17Max <= "001101011011110001";--3
					appSRA <= 3;
				elsif bluetoothData = x"86" then
					addressing17Max <= "001101111100100111";--4
					appSRA <= 3;
				elsif bluetoothData = x"87" then
					addressing17Max <= "001110011101011101";--5
					appSRA <= 3;
				elsif bluetoothData = x"88" then
					addressing17Max <= "001110111110010011";--6
					appSRA <= 3;
				elsif bluetoothData = x"89" then
					addressing17Max <= "001111011111001001";--7
					appSRA <= 3;
				elsif bluetoothData = x"8A" then
					addressing17Max <= "001111111111111111";--8
					appSRA <= 3;
				
				elsif bluetoothData = x"8D" then
					addressing17Max <= "001100011001111111";--1
					appSRA <= 4;
				elsif bluetoothData = x"8E" then
					addressing17Max <= "001100111010111011";--2
					appSRA <= 4;
				elsif bluetoothData = x"8F" then
					addressing17Max <= "001101011011110001";--3
					appSRA <= 4;
				elsif bluetoothData = x"90" then
					addressing17Max <= "001101111100100111";--4
					appSRA <= 4;
				elsif bluetoothData = x"91" then
					addressing17Max <= "001110011101011101";--5
					appSRA <= 4;
				elsif bluetoothData = x"92" then
					addressing17Max <= "001110111110010011";--6
					appSRA <= 4;
				elsif bluetoothData = x"93" then
					addressing17Max <= "001111011111001001";--7
					appSRA <= 4;
				elsif bluetoothData = x"94" then
					addressing17Max <= "001111111111111111";--8
					appSRA <= 4;
					
				-- ===================================
				-- Reverberation 
				-- ===================================
				elsif bluetoothData = x"64" then
				
					-- bluetoothDecimal = 100
					addressing17Max <= "000011111111111111";--0
					appSRA <= 1;
				else
				end if;
				-- ===================================	
				
				if key(3) = '1' then -- this will force to start 
					if mode = memRec then
						sram_oe_n 	<= 	'0';
						sram_we_n 	<= 	'0';
					elsif mode = memRec1 then
						sram_oe_n 	<= 	'0';
						sram_we_n 	<= 	'0';
						if key(1) = '1' then
							if aud_daclrck = '1' then
								if appMode = 1 or appMode = 0 then
									sram_dq	<= (to_stdlogicvector(to_bitvector(writedata_left(23 downto 8)) 	sra 0));
								elsif appMode = 2 then
									sram_dq	<= (to_stdlogicvector(to_bitvector(writedata_left(23 downto 8)) 	sra 0));
								end if;
								--sram_dq <= readdata_left(23 downto 8);
								ledg <= readdata_left(23 downto 16);
							else
								if appMode = 1 or appMode = 0 then
									sram_dq	<= (to_stdlogicvector(to_bitvector(writedata_right(23 downto 8)) 	sra 0));
								elsif appMode = 2 then
									sram_dq	<= (to_stdlogicvector(to_bitvector(writedata_right(23 downto 8)) 	sra 0));
								end if;
								--sram_dq <= readdata_right(23 downto 8);
								ledg <= readdata_right(23 downto 16);
							end if;
						else
							sram_dq <= ("0000000000000000");
						end if;
						-- (19 downto 4);
						-- (23 downto 8);
					elsif mode = memRead then
						sram_oe_n 	<= 	'0';
						sram_we_n 	<= 	'1';
					elsif mode = memRead1 then
						sram_oe_n 	<= 	'0';
						sram_we_n 	<= 	'1';
						soundBuffer <= (""&sram_dq&"00000000");
						ledr <=	sram_dq(15 downto 6);
					else
						sram_oe_n 	<= 	'1';
						sram_we_n 	<= 	'1';
						sram_dq 		<= 	ioLocker;
					end if;
				end if;
				
				if write_s = '0' then
					if falling_edge(clock_50) and sw(9) = '0'  then
						if stateSRAM < maxSRAM then
							stateSRAM <= stateSRAM + 1;
						end if;
						
						
						if		94 < stateSRAM and stateSRAM <= 189 then
							mode <= memRead; -- prepare to read
						elsif 189 < stateSRAM and stateSRAM <= 283 then 
							mode <= memRead1; -- read
						elsif 283 < stateSRAM and stateSRAM <= 378 then 
							mode <= memRec; -- prepare to Record
						elsif 378 < stateSRAM and stateSRAM <= 472 then 
							mode <= memRec1; -- record
						else
							mode <= memNULL; -- waiting to change the address
						end if;

					end if;
				else
					stateSRAM <= 0;
				end if;
		end process;
		
		-- write_s velocidade aproximadamente de 88.8889 kHz
		-- clock exato de 88.2048 kHz
		store:process (write_s)
			begin
				if falling_edge(to_stdulogic(to_bit(write_s))) and sw(9) = '0' then
					if addressing17Bits < addressing17Max then
						addressing17Bits <= addressing17Bits + oneBit;
					else
						addressing17Bits <= addressingStart;
					end if;
				end if;
				if key(2) = '0' then
					addressing17Bits <= addressingStart;
				end if;
		end process;
		
end Memory_SRAM;