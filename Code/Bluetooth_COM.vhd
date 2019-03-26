-- projeto_base -> bluetooth_module
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;
use ieee.Std_Logic_Unsigned.all;

entity bluetooth_module is
	port(
		-- custom port
		bluetoothData 		:	inout	std_logic_vector(7 downto 0);
	
		-- audio
		writedata_left,
		writedata_right: in std_logic_vector(23 downto 0);
		read_s, 
		write_s 			: 	in		std_logic;
		-- clock
		clock_24 : 	in bit_vector	(0 to 1);
		
		-- Comunication
		gpio_0 	:	in bit_vector	(0 to 39)--;
		
		-- Interface
		-- ledg		:	out std_logic_vector	(7 downto 0)
		
	);
end bluetooth_module;

architecture bluetooth of bluetooth_module is
	
	-- clock reducer
	signal clockCounter48KHz	: 	integer range 0 to 250 := 0;
	signal clock_48KHz			: 	std_ulogic := '0';
	
	-- rx of module
	signal rxCounter				:	integer range 0 to 63 := 0;
	signal rxStream				:	bit_vector (0 to 7);
	signal rxStandby				:	bit := '1';
	signal startBit				:	bit := '0';
	constant rxPin					:	integer := 10;
	
	begin
		--interface
		--ledg <= bluetoothData;
		bluetoothData(7) <= to_stdulogic(rxStream(7));
		bluetoothData(6) <= to_stdulogic(rxStream(6));
		bluetoothData(5) <= to_stdulogic(rxStream(5));
		bluetoothData(4) <= to_stdulogic(rxStream(4));
		bluetoothData(3) <= to_stdulogic(rxStream(3));
		bluetoothData(2) <= to_stdulogic(rxStream(2));
		bluetoothData(1) <= to_stdulogic(rxStream(1));
		bluetoothData(0) <= to_stdulogic(rxStream(0));
		
		-- clock reducer;
		process (clock_24(0))
			begin				
				if falling_edge(to_stdulogic(clock_24(0))) then			
					-- 48KHz
					if (clockCounter48KHz < 250) THEN
						clockCounter48KHz <= clockCounter48KHz + 1;
					else
						clockCounter48KHz <= 0;
						clock_48KHz <= not clock_48KHz;
					end if;
				
				end if;
		end process;
		
		
		-- RX read
		process (clock_48KHz)
			begin
				if falling_edge (clock_48KHz) then
					if rxStandby = '0' then --received the start bit
						if rxCounter < 48 then
							rxCounter <= rxCounter + 1;
						else
							rxCounter <= 0;
						end if;
						
						case rxCounter is
							when  5 =>
								rxStream(0) <= gpio_0(rxPin);
							when  8 =>
								rxStream(1) <= gpio_0(rxPin);
							when 13 =>
								rxStream(2) <= gpio_0(rxPin);
							when 18 =>
								rxStream(3) <= gpio_0(rxPin);
							when 23 =>
								rxStream(4) <= gpio_0(rxPin);
							when 28 =>
								rxStream(5) <= gpio_0(rxPin);
							when 33 =>
								rxStream(6) <= gpio_0(rxPin);
							when 38 =>
								rxStream(7) <= gpio_0(rxPin);
							when 43 =>
								-- end bit sender;
							when 47 =>
								startBit <= '1';
								rxStandby <= '1';
								
							when others =>
								
						end case;
					else
						if startBit = '0' and rxStandby = '1' then
							rxStandby <= '0';
						else
							startBit <= gpio_0(rxPin);
						end if;
					end if;
				end if;
		end process;
end bluetooth;