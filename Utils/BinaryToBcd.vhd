-- **********************************************************
--   Corso di Reti Logiche - Progetto Registratore Portatile
--   Andrea Carrer - 729101
--   Modulo BinaryToBcd.vhd
--   Versione 1.01 - 14.03.2013
-- **********************************************************

-- **********************************************************
-- Questo modulo converte un numero binario in BCD per
-- visualizzare numer decimali sul display a 7 segmenti.
-- Utilizza l'algoritmo "Shift and Add-3"
--  1. Shift a sinistra del numero binario.
--  2. Dopo 8 shift, il numero BCD e' nel formato centinaia, decine, unita'
--  3. Se il valore binario dei BCD e' > 4, aggiunge 3 al valore.
--  4. Vai a 1.
-- **********************************************************

library ieee;
use ieee.std_logic_1164.all;

entity BinaryToBcd is port (
        A: 			in std_logic_vector(7 downto 0);	
        ONES: 		out std_logic_vector(3 downto 0);	
        TENS: 		out std_logic_vector(3 downto 0);	
        HUNDREDS:	out std_logic_vector(1 downto 0));	
end BinaryToBcd;

architecture behaviour OF BinaryToBcd IS
    
    component Add3 is port (
        signal s_i: in  std_logic_vector(3 downto 0);	
        signal s_o: out std_logic_vector(3 downto 0)
        );	
	end component;

    signal c1 : std_logic_vector(3 downto 0);	
    signal c2 : std_logic_vector(3 downto 0);	
    signal c3 : std_logic_vector(3 downto 0);	
    signal c4 : std_logic_vector(3 downto 0);	
    signal c5 : std_logic_vector(3 downto 0);	
    signal c6 : std_logic_vector(3 downto 0);	
    signal c7 : std_logic_vector(3 downto 0);	
    signal d1 : std_logic_vector(3 downto 0);	
    signal d2 : std_logic_vector(3 downto 0);	
    signal d3 : std_logic_vector(3 downto 0);	
    signal d4 : std_logic_vector(3 downto 0);	
    signal d5 : std_logic_vector(3 downto 0);	
    signal d6 : std_logic_vector(3 downto 0);	
    signal d7 : std_logic_vector(3 downto 0);
    
BEGIN
    d1 			<= '0' & A(7 DOWNTO 5);	
    d2 			<= c1(2 DOWNTO 0) & A(4);	
    d3 			<= c2(2 DOWNTO 0) & A(3);	
    d4 			<= c3(2 DOWNTO 0) & A(2);	
    d5 			<= c4(2 DOWNTO 0) & A(1);	
    d6 			<= '0' & c1(3) & c2(3) & c3(3);	
    d7 			<= c6(2 DOWNTO 0) & c4(3);	
    ONES 		<= c5(2 DOWNTO 0) & A(0);	
    TENS 		<= c7(2 DOWNTO 0) & c5(3);	
    HUNDREDS	<= c6(3) & c7(3);	

    m1 : add3 port map ( d1, c1);	
    m2 : add3 port map ( d2, c2);	
    m3 : add3 port map ( d3, c3);	
    m4 : add3 port map ( d4, c4);	
    m5 : add3 port map ( d5, c5);	
    m6 : add3 port map ( d6, c6);	
    m7 : add3 port map ( d7, c7);	

END behaviour;