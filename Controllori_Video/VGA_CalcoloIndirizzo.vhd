-- **********************************************************
--   Corso di Reti Logiche - Progetto Registratore Portatile
--   Andrea Carrer - 729101
--   Modulo VGA_CalcoloIndirizzo.vhd
--   Versione 1.01 - 14.03.2013
-- **********************************************************

-- **********************************************************
-- Modulo trovato in rete, convertito da Verilog a VHDL
-- e successivamente adattato al progetto. Questo modulo
-- converte le coordinate in un indirizzo di memoria
-- Le coordinate sono calcolate sulla risoluzione di 320x240.
-- **********************************************************

library ieee;
   use ieee.std_logic_1164.all;
   use ieee.std_logic_unsigned.all;

entity VGA_CalcoloIndirizzo is

	-- "320x240": l'adattatore VGA usa un pixel di dimensioni 2x2.
	-- Ho usato questa risoluzione per non superare il limite di memoria a disposizione.
	-- 320x240 monocromatici = 76800 kbit - Il limite della memoria e' 240 kbit
	
   port (
      x            : in std_logic_vector(8 downto 0);
      y            : in std_logic_vector(7 downto 0);
      mem_address  : out std_logic_vector(16 downto 0)
   );
   
end VGA_CalcoloIndirizzo;

architecture behaviour of VGA_CalcoloIndirizzo is
   signal res_320x240 : std_logic_vector(16 downto 0);
   
	begin
	-- Indirizzo = y*WIDTH + x;
	-- In 320x240 il 320 e' scrivibile come due somme di potenze di due (256 + 64)
	-- e l'indirizzo diventa (y*256) + (y*64) + x, semplificando l'operazione d moltiplcazione
	-- che diventa uno shift piu' un'addizione.
	-- Viene aggiunto uno zero in posizione piu' signficativa per trattarli come interi senza segno.

	res_320x240 <= (('0' & y & "00000000") + ("00" & ('0' & y & "000000")) + ("0000000" & ('0' & x)));

	process (res_320x240)
	begin
		mem_address <= res_320x240;
	end process;

end behaviour;