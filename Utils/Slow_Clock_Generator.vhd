-- **********************************************************
--   Corso di Reti Logiche - Progetto Registratore Portatile
--   Andrea Carrer - 729101
--   Modulo Slow_Clock_Generator.vhd
--   Versione 1.01 - 14.03.2013
-- **********************************************************

-- **********************************************************
-- Generazione segnali di clock a bassa frequenza.
-- **********************************************************

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;
	use IEEE.std_logic_misc.all;

entity Slow_Clock_Generator is
		
	generic (
		COUNTER_BITS:			integer := 10;
		COUNTER_INC:			std_logic_vector(9 downto 0) := "0000000001"
	);
	
	port (
		clk:					in std_logic;
		reset:					in std_logic;
		enable_clk:				in std_logic;

		new_clk:				out std_logic;
		ris_edge:				out std_logic;
		fal_edge:				out std_logic;
		middle_of_high_level:	out std_logic;
		middle_of_low_level:	out std_logic
	);

end Slow_Clock_Generator;

architecture behaviour of Slow_Clock_Generator is

	signal clk_counter:	std_logic_vector (COUNTER_BITS downto 1);
	signal new_clk_sig:	std_logic;

begin

	new_clk <= new_clk_sig;
			
	process (clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				clk_counter	<= "0000000000";
			elsif (enable_clk = '1') then
				clk_counter	<= clk_counter + COUNTER_INC;
			end if;
		end if;
	end process;

	process (clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				new_clk_sig	<= '0';
			else
				new_clk_sig	<= clk_counter(COUNTER_BITS);
			end if;
		end if;
	end process;

	process (clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				ris_edge <= '0';
			else
				ris_edge <= (clk_counter(COUNTER_BITS) xor new_clk_sig) and (not new_clk_sig);
			end if;
		end if;
	end process;

	process (clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				fal_edge <= '0';
			else
				fal_edge <= (clk_counter(COUNTER_BITS) xor new_clk_sig) and new_clk_sig;
			end if;
		end if;
	end process;

	process (clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				middle_of_high_level <= '0';
			else
				middle_of_high_level <= (
				(clk_counter(COUNTER_BITS) and (not clk_counter((COUNTER_BITS - 1)))) 
				and AND_REDUCE(clk_counter((COUNTER_BITS - 2) downto 1)));
			end if;
		end if;
	end process;

	process (clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				middle_of_low_level <= '0';
			else
				middle_of_low_level <= (
				((not clk_counter(COUNTER_BITS)) and (not clk_counter(( COUNTER_BITS - 1 ))))
				and AND_REDUCE(clk_counter((COUNTER_BITS - 2) downto 1))) ;
			end if;
		end if;
	end process;

end behaviour;