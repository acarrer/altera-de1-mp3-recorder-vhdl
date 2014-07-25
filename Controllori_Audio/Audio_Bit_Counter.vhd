-- **********************************************************
--   Corso di Reti Logiche - Progetto Registratore Portatile
--   Andrea Carrer - 729101
--   Modulo Audio_Bit_Counter.vhd
--   Versione 1.01 - 14.03.2013
-- **********************************************************

-- **********************************************************
-- Modulo che conta i bit per il trasferimento seriale
-- del segnale audio.
-- **********************************************************

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;
	
entity Audio_Bit_Counter is
	generic(
		BIT_COUNTER_INIT: 				std_logic_vector(4 downto 0)  := "11111"
	);
	port(
		clk:							in std_logic;
		reset:							in std_logic;
		
		bit_clk_rising_edge:			in std_logic;
		bit_clk_falling_edge:			in std_logic;
		left_right_clk_rising_edge:		in std_logic;
		left_right_clk_falling_edge:	in std_logic;

		counting:						out std_logic
	);
end Audio_Bit_Counter;

architecture behaviour of Audio_Bit_Counter is

	signal reset_bit_counter:		std_logic;
	signal bit_counter:				std_logic_vector(4 downto 0);
	
begin

	reset_bit_counter <= left_right_clk_rising_edge or left_right_clk_falling_edge;
	
	process(clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				bit_counter <= "00000";
			elsif (reset_bit_counter = '1') then
				bit_counter <= BIT_COUNTER_INIT;
			elsif ((bit_clk_falling_edge = '1') and (bit_counter > "00000")) then
				bit_counter <= bit_counter - "00001";
			end if;
		end if;
	end process;

	process(clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				counting <= '0';
			elsif (reset_bit_counter = '1') then
				counting <= '1';
			elsif ((bit_clk_falling_edge = '1') and (bit_counter = "00000")) then
				counting <= '0';
			end if;
		end if;
	end process;

end behaviour;