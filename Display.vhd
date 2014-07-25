-- **********************************************************
--   Corso di Reti Logiche - Progetto Registratore Portatile
--   Andrea Carrer - 729101
--   Modulo Display.vhd
--   Versione 1.03 - 21.03.2013
-- **********************************************************

-- **********************************************************
-- Gestisce il display su VGA 320x240.
-- 1 bit per pixel (monocromatico).
-- **********************************************************

library ieee;
   USE ieee.std_logic_1164.all;
   USE ieee.std_logic_unsigned.all;

entity Display is
   generic (
      sweep_delay  : std_logic_vector(31 downto 0) 	:= "00000000000000000010011100010000"; 	-- 10000
      xmax         : std_logic_vector(8 downto 0) 	:= "100111111"; 						-- 319; // Massimo degli x
      ymax         : std_logic_vector(7 downto 0) 	:= "11101111"; 							-- 239;	// Massimo degli y
      st_ploty     : std_logic := '0';
      st_done      : std_logic := '1'
   );
   port (
      clock        : in std_logic;
      reset        : in std_logic;
      freeze       : in std_logic;
      data         : in std_logic_vector(15 downto 0);
      x            : inout std_logic_vector(8 downto 0);
      y            : inout std_logic_vector(7 downto 0);
      color        : inout std_logic;
      plot         : inout std_logic
   );
end Display;

architecture behaviour of Display is
   signal delay_counter : std_logic_vector(31 downto 0);
   signal st            : std_logic;
   signal streg         : std_logic;
   signal buff_sig 		: std_logic_vector(8 downto 0);
begin

	---------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------- FSM gestione VGA
	---------------------------------------------------------------------------------------------

   process (all)
   begin
      st <= streg;
      case streg is
         when st_ploty =>
            if y = ymax then
               st <= st_done;
            end if;
         when st_done =>
            IF (freeze = '0') AND (delay_counter = sweep_delay) then
               st <= st_ploty;
            end if;
      end case;
   end process;
   
   process (clock)
   begin
      if rising_edge(clock) then
         if (reset = '1') then
            streg <= st_done;
         else
            streg <= st;
         end if;
      end if;
   end process;
  
   buff_sig <= "000000000" when (x = xmax) else x + "000000001";
   
   -- Contatore X				
   process (clock)
   begin
      if (rising_edge(clock)) then
         if (reset = '1') then
            delay_counter <= "00000000000000000000000000000000";
            x <= "000000000";
         elsif (streg = st_done) then
            if (delay_counter = sweep_delay) then
               delay_counter <= "00000000000000000000000000000000";
               x <= buff_sig;
            else
               delay_counter <= delay_counter + "00000000000000000000000000000001";
            end if;
         end if;
      end if;
   end process;
  
   -- Contatore Y
   process (clock)
   begin
      if (rising_edge(clock)) then
         if (reset = '1' or (streg = st_done)) then
            y <= "00000000";
         elsif (y < ymax) then
            y <= y + "00000001";
		end if;
      end if;
   end process;
   
   -- Sincronizzazione
   plot <= '1' when (streg = st_ploty) else '0';  
   
   -- Determino se devo visualizzare o no il pixel 
   -- 01111000 = 120 --> riga centrale del display
   -- data(15) = segno
    color <= '1' when (y= "01111000" + (data(15)
				& data(14) & data(12) & data(10) & data(8) & data(6) & data(4) & data(2))) else '0';
    --color <= '1' when (y= "01111000" + (data(15) & data(6 downto 0))) else '0';
  
end behaviour;