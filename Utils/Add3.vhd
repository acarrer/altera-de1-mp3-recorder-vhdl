-- **********************************************************
--   Corso di Reti Logiche - Progetto Registratore Portatile
--   Andrea Carrer - 729101
--   Modulo Add3.vhd
--   Versione 1.01 - 14.03.2013
-- **********************************************************

-- **********************************************************
-- Questo modulo serve al BinaryToBcd:
-- Se il valore binario dei BCD e' > 4, aggiunge 3 al valore.
-- **********************************************************

library ieee;
USE ieee.std_logic_1164.all;

entity Add3 is port (
        signal s_i	: in  std_logic_vector(3 downto 0);	
        signal s_o 	: out std_logic_vector(3 downto 0)
        );	
end Add3;

architecture behaviour OF Add3 IS

begin
    process (s_i)
    begin
        case s_i is
         when B"0000" =>	s_o <= B"0000";	
         when B"0001" =>	s_o <= B"0001";	
         when B"0010" =>	s_o <= B"0010";	
         when B"0011" =>	s_o <= B"0011";	
         when B"0100" =>	s_o <= B"0100";	
         when B"0101" =>	s_o <= B"1000";	
         when B"0110" =>	s_o <= B"1001";	
         when B"0111" =>	s_o <= B"1010";	
         when B"1000" =>	s_o <= B"1011";	
         when B"1001" =>	s_o <= B"1100";	
         when others =>		s_o <= B"0000";	
        end case;
    end process;

end behaviour;