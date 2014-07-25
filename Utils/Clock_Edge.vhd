-- **********************************************************
--   Corso di Reti Logiche - Progetto Registratore Portatile
--   Andrea Carrer - 729101
--   Modulo Clock_Edge.vhd
--   Versione 1.01 - 14.03.2013
-- **********************************************************

-- **********************************************************
-- Trova fronti di un clock alla frequenza di un altro clock.
-- **********************************************************

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;
	
entity Clock_Edge is port (
	clk:			in std_logic;
	reset:			in std_logic;
	test_clk:		in std_logic;
	ris_edge:		out std_logic;
	fal_edge:		out std_logic
);

end Clock_Edge;

architecture behaviour of Clock_Edge is

	signal found_edge:		std_logic;
	signal cur_test_clk:	std_logic;
	signal last_test_clk:	std_logic;

begin

	ris_edge <= found_edge and cur_test_clk;
	fal_edge <= found_edge and last_test_clk;
	found_edge <= last_test_clk xor cur_test_clk;

	process (clk)
	begin
		if (rising_edge(clk)) then
			cur_test_clk	<= test_clk;
		end if;
	end process;

	process (clk)
	begin
		if (rising_edge(clk)) then
			last_test_clk	<= cur_test_clk;
		end if;
	end process;

end behaviour;