-- **********************************************************
--   Corso di Reti Logiche - Progetto Registratore Portatile
--   Andrea Carrer - 729101
--   Modulo PlayRecord.vhd
--   Versione 1.01 - 14.03.2013
-- **********************************************************

-- **********************************************************
-- FSM per la gestione di Registrazione e Riproduzione Audio.
-- **********************************************************

library ieee;
   USE ieee.std_logic_1164.all;
   USE ieee.std_logic_unsigned.all;

entity PlayRecord is
   generic (
      st_start            : std_logic_vector(2 downto 0) := "000";  -- Valori di stato della FSM
      st_rc_audio_wait    : std_logic_vector(2 downto 0) := "001";
      st_rc_ram_nextaddr  : std_logic_vector(2 downto 0) := "010";
      st_rc_ram_wait      : std_logic_vector(2 downto 0) := "011";
      st_pl_ram_rd        : std_logic_vector(2 downto 0) := "100";
      st_pl_audio_wait    : std_logic_vector(2 downto 0) := "101";
      st_pl_ram_nextaddr  : std_logic_vector(2 downto 0) := "110";
      st_input_check      : std_logic_vector(2 downto 0) := "111"
   );
   port (
      CLOCK_50				: in std_logic;
      CLOCK_1S				: in std_logic;
      reset					: in std_logic;
      ram_addr				: out std_logic_vector(21 downto 0);
      ram_data_in			: out std_logic_vector(15 downto 0);
      ram_read				: out std_logic;
      ram_write				: out std_logic;
      ram_data_out			: in std_logic_vector(15 downto 0);
      ram_valid				: in std_logic;
      ram_waitrq			: in std_logic;
      audio_out				: out std_logic_vector(15 downto 0);
      audio_in				: in std_logic_vector(15 downto 0);
      audio_out_allowed		: in std_logic;
      audio_in_available	: in std_logic;
      write_audio_out		: out std_logic;
      read_audio_in			: out std_logic;
      play					: in std_logic;
      rec					: in std_logic;
      pause					: in std_logic;
      speed					: in std_logic_vector(1 downto 0);
      
      ram_addr_max			: in std_logic_vector(21 downto 0);
      playLimitReached		: inout std_logic;
      
      secondsCounter		: inout std_logic_vector(7 downto 0)
   );
end PlayRecord;

architecture behaviour OF PlayRecord IS
  
   signal st					: std_logic_vector(2 downto 0);
   signal streg					: std_logic_vector(2 downto 0);
   
   -- Segnali buffer
   signal ram_addr_sig			: std_logic_vector(21 downto 0);
   signal ram_data_in_sig		: std_logic_vector(15 downto 0);
   signal ram_read_sig			: std_logic;
   signal ram_write_sig			: std_logic;
   signal audio_out_sig			: std_logic_vector(15 downto 0);
   signal write_audio_out_sig	: std_logic;
   signal read_audio_in_sig		: std_logic;
   
   signal secondsIncrement		: std_logic_vector(7 downto 0);
  
begin
   
   secondsIncrement <= "000000" & speed + "00000001";		-- Determina lo step di incremento dei secondi in Play
   
   -- Segnali buffer
   ram_addr 		<= ram_addr_sig;
   ram_data_in 		<= ram_data_in_sig;
   ram_read 		<= ram_read_sig;
   ram_write 		<= ram_write_sig;
   audio_out 		<= audio_out_sig;
   write_audio_out 	<= write_audio_out_sig;
   read_audio_in 	<= read_audio_in_sig;
   
   playLimitReached <= '1' when ram_addr_max <= ram_addr_sig else '0';
   
   process (all)
   begin
      st <= streg;
      
		---------------------------------------------------------------------------------------------
		---------------------------------------------------------------- FSM della fase di Play e Rec
 		---------------------------------------------------------------------------------------------
     
      case streg is
		---------------------------------------------- STATO START
         when st_start =>
            st <= st_input_check;					-- Da start va a input_check
            
		---------------------------------------------- STATO IDLE
         when st_input_check =>
            if pause = '0' then						-- Stato "idle": determina la prossima operazione
				if play = '1' then
					if playLimitReached = '0' then
						st <= st_pl_audio_wait;		-- Play
					end if;
				elsif rec = '1' then
					st <= st_rc_audio_wait;			-- Rec: attesa segnale audio
				else
					st <= st_start;					-- Ne' Play ne' Rec: non fa nulla
               end if;
            end if;
         
		---------------------------------------------- GESTIONE REGSTRAZIONE
         when st_rc_audio_wait =>
            if (audio_in_available = '1') then		
               st <= st_rc_ram_nextaddr;			-- Rec: passa a indirizzo di memoria successivo
            end if;
         when st_rc_ram_nextaddr =>
            st <= st_rc_ram_wait;					-- Rec: scrittura in memoria
         when st_rc_ram_wait =>
            if (ram_waitrq = '0') then
               st <= st_input_check;				-- Rec: scrittura terminata e ritorno
            end if;
         
		---------------------------------------------- GESTIONE RIPRODUZIONE
         when st_pl_audio_wait =>
            if (audio_out_allowed = '1') then
               st <= st_pl_ram_rd;					-- Play: leggi da RAM
            end if;
         when st_pl_ram_rd =>
            if (ram_waitrq ='0' and ram_valid = '1') then
               st <= st_pl_ram_nextaddr;			-- Play: passa a indirizzo di memoria successivo
            end if;
         when st_pl_ram_nextaddr =>
            st <= st_input_check;					-- Play: lettura completata e ritorno
      end case;
   end process;
      
   process (CLOCK_50)
   begin
      if rising_edge(CLOCK_50) then
         if (reset = '1') then
            streg <= st_input_check;
         else
            streg <= st;
         end if;
      end if;
   end process;
   
   -- Contatore indirizzo RAM
   process (CLOCK_50)
   begin
      if rising_edge(CLOCK_50) then
         if (reset = '1') then
            ram_addr_sig <= "0000000000000000000000";
         else
		   if (streg = st_start) then 
				ram_addr_sig <= "0000000000000000000000";
		   elsif (streg = st_rc_ram_nextaddr) then
			  ram_addr_sig <= ram_addr_sig + "0000000000000000000001";
		   elsif streg = st_pl_ram_nextaddr then	-- La velocita' fa "saltare" n banchi di RAM
			  ram_addr_sig <= ram_addr_sig + "0000000000000000000001" + ("00000000000000000000" & speed);
		   end if;
         end if;
      end if;
   end process;
   
     -- Contatore secondi
	process (CLOCK_50, CLOCK_1S)
	begin
     if rising_edge(CLOCK_1S) then
         if (reset = '1') then
            secondsCounter <= "00000000";
         else
			if (streg = st_start) then 
				secondsCounter <= "00000000";
			elsif pause = '0' then
				if play = '1' then
					if playLimitReached = '0' then  -- secondsIncrement dipende dalla velocita'
						secondsCounter <= secondsCounter + secondsIncrement;
					else
						secondsCounter <= "00000000";
					end if;
				elsif rec = '1' then
					secondsCounter <= secondsCounter + "00000001";
				else
					secondsCounter <= "00000000";
				end if;
            end if;
         end if;
      end if;
   end process;

   -- Controller Audio
   read_audio_in_sig <= '1' when ((streg = st_rc_ram_nextaddr) or (streg = st_start and audio_in_available = '1')) else '0';
   write_audio_out_sig <= '1' when (st = st_pl_ram_nextaddr) else '0';
   
   -- Connessione con SDRAM
   ram_data_in_sig <= audio_in;
   audio_out_sig <= ram_data_out;
   ram_write_sig <= '1' when (streg = st_rc_ram_wait) else '0';
   ram_read_sig <= '1' when (streg = st_pl_ram_rd) else '0';
   
END behaviour;