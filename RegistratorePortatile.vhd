-- **********************************************************
--   Corso di Reti Logiche - "Mp3 Recorder" Project
--   Andrea Carrer - 729101
--   Module RegistratorePortatile.vhd
--   Version 1.02 - 18.03.2013
-- **********************************************************

-- **********************************************************
-- Main Module, written in VHDL.
-- Definisce la logica e le connessioni tra i diversi moduli:
-- - PlayRecord: 		gestione comandi registratore
-- - Display:			gestione segnali grafica
-- - Audio_Controller:		interfaccia con il chip WM8731
-- - VGA_Adapter:		interfaccia con l'uscita VGA
-- - SDRAM:			interfaccia con la SDRAM
-- E gestisce i componenti I/O della scheda Altera DE1
-- **********************************************************

-- --------------------------------------------------------------------------------------------
-- --------------------------------------------------------------------- Main Module definition
-- --------------------------------------------------------------------------------------------

library ieee;
   USE ieee.std_logic_1164.all;
   USE ieee.std_logic_unsigned.all;

entity RegistratorePortatile is port(
	DRAM_DQ:	inout std_logic_vector(15 downto 0);	--	SDRAM Data bus 16 Bits
	DRAM_ADDR:	out std_logic_vector(11 downto 0);		--	SDRAM Address bus 12 Bits
	DRAM_LDQM:  buffer std_logic;						--	SDRAM Low-byte Data Mask 
	DRAM_UDQM:	buffer std_logic;						--	SDRAM High-byte Data Mask
	DRAM_WE_N:	out std_logic;							--	SDRAM Write Enable
	DRAM_CAS_N:	out std_logic;							--	SDRAM Column Address Strobe
	DRAM_RAS_N:	out std_logic;							--	SDRAM Row Address Strobe
	DRAM_CS_N:	out std_logic;							--	SDRAM Chip Select
	DRAM_BA_0:	buffer std_logic;						--	SDRAM Bank Address 0
	DRAM_BA_1:	buffer std_logic;						--	SDRAM Bank Address 1
	DRAM_CLK:	out std_logic;							--	SDRAM Clock
	DRAM_CKE:	out std_logic;							--	SDRAM Clock Enable

	CLOCK_50:	in std_logic;							--	On Board 50 MHz

	KEY:		in std_logic_vector(3 downto 0);		--	Pushbutton[3:0]
	SW:			in std_logic_vector(9 downto 0);		--	Toggle Switch[9:0]
	HEX0:		out std_logic_vector(6 downto 0);		--	Seven Segment Digit 0
	HEX1:		out std_logic_vector(6 downto 0);		--	Seven Segment Digit 1
	HEX2:		out std_logic_vector(6 downto 0);		--	Seven Segment Digit 2
	HEX3:		out std_logic_vector(6 downto 0);		--	Seven Segment Digit 3
	LEDG:		out std_logic_vector(7 downto 0);		--	LED Green[7:0]
	LEDR:		out std_logic_vector(9 downto 0);		--	LED Red[9:0]

	AUD_ADCLRCK:inout std_logic;						--	Audio CODEC ADC LR Clock
	AUD_ADCDAT:	in std_logic;							--	Audio CODEC ADC Data
	AUD_DACLRCK:inout std_logic;						--	Audio CODEC DAC LR Clock
	AUD_DACDAT:	out std_logic;							--	Audio CODEC DAC Data
	AUD_BCLK:	inout std_logic;						--	Audio CODEC Bit-Stream Clock
	AUD_XCK:	out std_logic;							--	Audio CODEC Chip Clock

	I2C_SDAT:	inout std_logic;						--	I2C Data
	I2C_SCLK:	out std_logic;							--	I2C Clock

	VGA_CLK:	inout std_logic;   						--	VGA Clock
	VGA_HS:		out std_logic;							--	VGA H_SYNC
	VGA_VS:		out std_logic;							--	VGA V_SYNC
	VGA_BLANK:	out std_logic;							--	VGA BLANK
	VGA_SYNC:	out std_logic;							--	VGA SYNC
	VGA_R:		out std_logic_vector(9 downto 0);   	--	VGA Red[9:0]
	VGA_G:		out std_logic_vector(9 downto 0);	 	--	VGA Green[9:0]
	VGA_B:		out std_logic_vector(9 downto 0)  		--	VGA Blue[9:0]
);
end RegistratorePortatile;

-- --------------------------------------------------------------------------------------------
-- ------------------------------------------------------------------------ Definizione segnali
-- --------------------------------------------------------------------------------------------

architecture behaviour of RegistratorePortatile is

	-------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------- Componenti usati
	-------------------------------------------------------------------------------------------
	
	component SDRAM_pll is port(
		inclk0	: in std_logic;
		c0		: out std_logic;
		c1		: out std_logic;
		c2		: out std_logic 
		);
	end component;

	component sdram is port(
		az_addr:			in std_logic_vector(21 downto 0);
		az_be_n:			in std_logic_vector(1 downto 0);
		az_cs:				in std_logic;
		az_data:			in std_logic_vector(15 downto 0);
		az_rd_n:			in std_logic;
		az_wr_n:			in std_logic;
		clk:				in std_logic;
		reset_n:			in std_logic;

		za_data:			out std_logic_vector(15 downto 0);
		za_valid:			out std_logic;
		za_waitrequest:		out std_logic;
		zs_addr:			out std_logic_vector(11 downto 0);
		zs_ba:				out std_logic_vector(1 downto 0);
		zs_cas_n:			out std_logic;
		zs_cke:				out std_logic;
		zs_cs_n:			out std_logic;
		zs_dq:				inout std_logic_vector(15 downto 0);
		zs_dqm:				out std_logic_vector(1 downto 0);
		zs_ras_n:			out std_logic;
		zs_we_n:			out std_logic
		);
	end component;
	
	component Audio_Controller is port(
		clk:						in std_logic;
		reset:						in std_logic;
		clear_audio_in_memory:		in std_logic;
		read_audio_in:				in std_logic;
		clear_audio_out_memory:		in std_logic;
		left_channel_audio_out: 	in std_logic_vector(32 downto 1); -- TODO parametrizzare con AUDIO_DATA_WIDTH 
		right_channel_audio_out: 	in std_logic_vector(32 downto 1); -- TODO parametrizzare con AUDIO_DATA_WIDTH 
		write_audio_out:			in std_logic;
		AUD_ADCDAT:					in std_logic;

		AUD_BCLK:					inout std_logic;
		AUD_ADCLRCK:				inout std_logic;
		AUD_DACLRCK:				inout std_logic;
		I2C_SDAT:					inout std_logic;

		audio_in_available:			out std_logic;
		left_channel_audio_in: 		buffer std_logic_vector(32 downto 1); -- TODO parametrizzare con AUDIO_DATA_WIDTH 
		right_channel_audio_in: 	out std_logic_vector(32 downto 1); -- TODO parametrizzare con AUDIO_DATA_WIDTH 

		audio_out_allowed:			out std_logic;
		AUD_XCK:					out std_logic;
		AUD_DACDAT:					out std_logic;
		I2C_SCLK:					out std_logic;

		useMicInput:				in std_logic
		);
	end component;
	
	component PlayRecord is port (
		CLOCK_50			: in std_logic;
		CLOCK_1S			: in std_logic;
		reset				: in std_logic;
		ram_addr			: out std_logic_vector(21 downto 0);
		ram_data_in			: out std_logic_vector(15 downto 0);
		ram_read			: out std_logic;
		ram_write			: out std_logic;
		ram_data_out			: in std_logic_vector(15 downto 0);
		ram_valid			: in std_logic;
		ram_waitrq			: in std_logic;
		audio_out			: out std_logic_vector(15 downto 0);
		audio_in			: in std_logic_vector(15 downto 0);
		audio_out_allowed		: in std_logic;
		audio_in_available		: in std_logic;
		write_audio_out			: out std_logic;
		read_audio_in			: out std_logic;
		play				: in std_logic;
		rec				: in std_logic;
		pause				: in std_logic;
		speed				: in std_logic_vector(1 downto 0);

		ram_addr_max			: in std_logic_vector(21 downto 0);
		playLimitReached		: inout std_logic;

		secondsCounter			: inout std_logic_vector(7 downto 0)
	   );
	end component;

	component VGA_Adapter is port(
		resetn:		in std_logic;
		clock:		in std_logic;
		clock_25:	in std_logic;
		colour:		in std_logic;
		x:			in std_logic_vector(8 downto 0);	-- x coordinate
		y:			in std_logic_vector(7 downto 0);	-- y coordinate
		plot:		in std_logic;					-- Quando e'=1, il pixel (x,y) cambiera' colore (bisogna plottare)
										-- Segnali per il DAC per pilotare the monitor.
		VGA_R:		out std_logic_vector(9 downto 0);
		VGA_G:		out std_logic_vector(9 downto 0);
		VGA_B:		out std_logic_vector(9 downto 0);
		VGA_HS:		out std_logic;
		VGA_VS:		out std_logic;
		VGA_BLANK:	out std_logic;
		VGA_SYNC:	out std_logic
		);
	end component;

	component Display is port (
		clock        : in std_logic;
		reset        : in std_logic;
		freeze       : in std_logic;
		data         : in std_logic_vector(15 downto 0);
		x            : inout std_logic_vector(8 downto 0);
		y            : inout std_logic_vector(7 downto 0);
		color        : inout std_logic;
		plot         : inout std_logic
		);
	end component;
	
	component BinaryToBcd is port (
        A 		 : in std_logic_vector(7 downto 0);	
        ONES 	 : out std_logic_vector(3 downto 0);	
        TENS 	 : out std_logic_vector(3 downto 0);	
        HUNDREDS : out std_logic_vector(1 downto 0)
        );	
	end component;

	component hex2seg is port (
		hex: in std_logic_vector(3 downto 0);
		seg: out std_logic_vector(6 downto 0)
	   );
	end component;

	-- Segnali usati per leggere e scrivere dalla RAM
	signal ram_addr:					std_logic_vector(21 downto 0);	-- Indirizzamento a 22 bit
	signal ram_data_in, ram_data_out:			std_logic_vector(15 downto 0);	-- Bus dati a 16 bit I/O
	signal ram_valid, ram_waitrq, ram_read, ram_write:	std_logic;						-- Segnali di abilitazione per lettura/scrittura

	signal ram_addr_max:					std_logic_vector(21 downto 0);	-- Memorizza l'ultimo banco di RAM memorizzato
	signal playLimitReached:				std_logic;						-- A 1 se durante il play si raggiunge la fine della registrazione

	-- Segnali per gestione lettura/scrittura audio
	signal audio_out, audio_in:		 		std_logic_vector(15 downto 0);	-- Bus a 16 bit
	signal audio_out_allowed, audio_in_available:		std_logic;						-- Segnali di controllo abilitazione lettura/scrittura audio
	signal write_audio_out, read_audio_in:			std_logic;

	-- Segnali per interfaccia con VGA
	signal vga_color:					std_logic;						-- Colore (monocromatico, pixel acceso/spento)
	signal vga_x:						std_logic_vector(8 downto 0);	-- x massimo = 319 (9 bit)
	signal vga_y:						std_logic_vector(7 downto 0);	-- y massimo = 239 (8 bit)
	signal vga_plot:					std_logic;						-- Abilitazione a scrittura pixel

	-- Visualizzo l'uscita se sono in Play, altrimenti visualizzo l'ingresso del microfono
	signal display_data:			 					std_logic_vector(15 downto 0);
	signal display_data_scaled:		 					std_logic_vector(15 downto 0);	-- Dati in scala usati per VGA e led rossi (volume)

	signal useMicInput:									std_logic;						-- Quando e' a 1 usa il microfono, altrimenti il LineIn

	signal blink_cnt:									std_logic_vector(25 downto 0);	-- Usato per blink pausa

	-- Contatore di secondi
	signal secondsCounter:								std_logic_vector(7 downto 0);	-- Contatore di secondi durante Play & Rec
	signal secondsCounter0, secondsCounter1:			std_logic_vector(3 downto 0);	-- BCD
	signal secondsCounter2:								std_logic_vector(1 downto 0);	-- BCD
	signal seconds_max:									std_logic_vector(7 downto 0);											-- Memorizza i secondi memorizzati con l'ultima registrazione
	signal seconds_max0, seconds_max1:					std_logic_vector(3 downto 0); 	-- BCD
	signal seconds_max2:								std_logic_vector(1 downto 0); 	-- BCD
	
	signal cnt_clock:									integer;
	signal CLOCK_1S:									std_logic;

	-----------------------------------------------------------------------------------------------
	------------------------------------------------------------ Definizione input dalla Altera DE1
	-----------------------------------------------------------------------------------------------

	-- Tasti e switch per comandi
	signal reset:			std_logic := 					not KEY(0);					-- Reset del sistema
	signal AudioInChanged:	std_logic :=					not KEY(1);					-- Gestione del soft reset del chip audio
	signal DisplayRamAddr:	std_logic :=					not KEY(2);					-- Se premuto visualizza l'indirizzo RAM anziche' i secondi
	signal play_Cmd:		std_logic := 					SW(0);						-- Riproduce l'audio
	signal pause_Cmd:		std_logic :=					SW(1);						-- Mette in pausa
	signal record_Cmd:		std_logic :=					SW(2);						-- Registra
	signal speed:			std_logic_vector(1 downto 0) :=	SW(4 downto 3);				-- Settaggi di velocita riproduzione
	signal scale:			std_logic_vector(1 downto 0) :=	SW(6 downto 5);				-- Scala di visualizzazione dell'onda
	signal showMaxAddr:		std_logic :=					SW(7);						-- Visualizzazione del limite dell'ultima registrazione

	-----------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------- Segnali di buffer
	-----------------------------------------------------------------------------------------------
	
	-- Segnali per display a 7 segmenti
	signal h0_sig:						std_logic_vector(3 downto 0);
	signal h1_sig:						std_logic_vector(3 downto 0);
	signal h2_sig:						std_logic_vector(3 downto 0);
	signal h3_sig:						std_logic_vector(3 downto 0);
	
	signal ramMaxAddr_sig:				std_logic_vector(1 downto 0); -- Serve per assegnare h0 e h1

	signal zs_ba_sig:					std_logic_vector(1 downto 0);
	signal zs_dqm_sig:					std_logic_vector(1 downto 0);
	signal left_channel_audio_in_sig:	std_logic_vector(32 downto 1);

begin

	display_data <= audio_out when play_Cmd='1' else audio_in;

	-----------------------------------------------------------------------------------------------
	--------------------------------------------------- Definizione output diretti sulla Altera DE1
	-----------------------------------------------------------------------------------------------

	-- Spie per livello audio (volume) sui led rossi
	LEDR(0) <= '0' when display_data_scaled(15)='1' else display_data_scaled(0);
	LEDR(1) <= '0' when display_data_scaled(15)='1' else display_data_scaled(2);
	LEDR(2) <= '0' when display_data_scaled(15)='1' else display_data_scaled(4);
	LEDR(3) <= '0' when display_data_scaled(15)='1' else display_data_scaled(6);
	LEDR(4) <= '0' when display_data_scaled(15)='1' else display_data_scaled(8);
	LEDR(5) <= '0' when display_data_scaled(15)='1' else display_data_scaled(10);
	LEDR(6) <= '0' when display_data_scaled(15)='1' else display_data_scaled(12);
	LEDR(7) <= '0' when display_data_scaled(15)='1' else display_data_scaled(14);

	-- Spia per la pausa
	LEDG(7) <= blink_cnt(25) when pause_Cmd='1' and (play_Cmd='1' or record_Cmd='1') else '0';
	LEDG(6) <= play_Cmd and playLimitReached;

	-- Spia per reset
	LEDG(0) <= reset;

	-- Spia per input audio
	LEDG(1) <= useMicInput;

	-- Clock 1S (debug)
	LEDG(2) <= 
		CLOCK_1S 
		and (play_Cmd or record_Cmd)
		and (not pause_Cmd)
		and (not playLimitReached);

	-- Led non usati
	LEDR(9 downto 8) <= "00";
	LEDG(5 downto 3) <= "000";
	
	-----------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------- Segnali di buffer
	-----------------------------------------------------------------------------------------------
	
	-- Visualizzo l'uscita se sono in Play, altrimenti visualizzo l'ingresso del microfono
	display_data				<= audio_out when play_Cmd='1' else audio_in;

	ramMaxAddr_sig 				<= DisplayRamAddr & showMaxAddr;

	with ramMaxAddr_sig select
		h0_sig <= 
			ram_addr_max(17 downto 14)	when "11",	-- Mostra Max Ram Address
			ram_addr(17 downto 14)		when "10",	-- Mostra Ram Address
			seconds_max0				when "01",	-- Mostra Max Secondi
			secondsCounter0				when "00",	-- Mostra secondi
			"0000"						when others;

	with ramMaxAddr_sig select
		h1_sig <= 
			ram_addr_max(21 downto 18)	when "11",	-- Mostra Max Ram Address
			ram_addr(21 downto 18)		when "10",	-- Mostra Ram Address
			seconds_max1				when "01",	-- Mostra Max Secondi
			secondsCounter1				when "00",	-- Mostra secondi
			"0000"						when others;
	
	h2_sig 						<= "00" & scale;
	h3_sig 						<= "00" & speed;

	zs_ba_sig					<= DRAM_BA_1 & DRAM_BA_0;
    zs_dqm_sig 					<= DRAM_UDQM & DRAM_LDQM;
    left_channel_audio_in_sig 	<= audio_in & "XXXXXXXXXXXXXXXX";

	-----------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------- Processi
	-----------------------------------------------------------------------------------------------

	-- Intercetto il cambio di input per generare un "soft reset" del codec
	-- Visto che il settaggio della periferica deve essere fatto allo startup del CODEC

	process (AudioInChanged)
	begin
		if rising_edge(AudioInChanged) then
			useMicInput <= not useMicInput;
		end if;
	end process;
			
	-- Calcolo dei dati in base alla scala scelta: piu' e' alto il valore di scala piu'
	-- Viene ridotta l'altezza della forma d'onda visualizzata
	process (all)
	begin
		case(scale) is
			when "00" => display_data_scaled <= display_data;
			when "01" => display_data_scaled <= display_data(15)
										   & display_data(15)
										   & display_data(15)
										   & display_data(15)
										   & display_data(15)
										   & display_data(14 downto 4);
			when "10" => display_data_scaled <= display_data(15)
										   & display_data(15)
										   & display_data(15)
										   & display_data(15)
										   & display_data(15)
										   & display_data(15)
										   & display_data(15)
										   & display_data(15)
										   & display_data(15)
										   & display_data(14 downto 8);
			when "11" => display_data_scaled <= display_data(15)
										   & display_data(15)
										   & display_data(15)
										   & display_data(15)
										   & display_data(15)
										   & display_data(15)
										   & display_data(15)
										   & display_data(15)
										   & display_data(15)
										   & display_data(15)
										   & display_data(15)
										   & display_data(15)
										   & display_data(15)
										   & display_data(14 downto 12);
		end case;
	end process;

	-- Blinking della pausa
	process (CLOCK_50)
	begin
		if rising_edge(CLOCK_50) then
			blink_cnt <= blink_cnt + 1;
		end if;
	end process;

	-- Memorizzazione dell'ultimo indirizzo registrato
	process (record_Cmd)
	begin
		if falling_edge(record_Cmd) then
			ram_addr_max <= ram_addr;
			seconds_max <= secondsCounter;
		end if;
	end process;

	-- Generazione clock a 2 Hz per contare i secondi
	process (CLOCK_50)
	begin
		if rising_edge(CLOCK_50) then
			if (cnt_clock = 25000000) then
				CLOCK_1S <= not CLOCK_1S;
				cnt_clock <= 0;
			else
				cnt_clock <= cnt_clock + 1;
			end if;
		end if;
	end process;
	
	
	-----------------------------------------------------------------------------------------------
	----------------------------------------------------------------------- Collegamento Componenti
	-----------------------------------------------------------------------------------------------
	
	-- Modulo PLL generato con la megafunction ALTPLL
	SDRAM_PLL_Entity: SDRAM_PLL port map(	
		inclk0			=> CLOCK_50,
		c0				=> DRAM_CLK, 
		c1				=> VGA_CLK, 
		c2				=> AUD_XCK
		);
		  
	-- Modulo generato dal SOPC builder
	SDRAM_Entity: sdram port map(
		az_addr			=> ram_addr,
		az_be_n			=> "00",
		az_cs			=> '1',
		az_data			=> ram_data_in,
		az_rd_n			=> not ram_read,
		az_wr_n			=> not ram_write,
		clk				=> CLOCK_50,
		reset_n			=> not reset,
		za_data			=> ram_data_out,
		za_valid		=> ram_valid,
		za_waitrequest	=> ram_waitrq,
		zs_addr 		=> DRAM_ADDR,
		zs_ba			=> zs_ba_sig,
		zs_cas_n		=> DRAM_CAS_N,
		zs_cke			=> DRAM_CKE,
		zs_cs_n			=> DRAM_CS_N,
		zs_dq			=> DRAM_DQ,
		zs_dqm			=> zs_dqm_sig,
		zs_ras_n		=> DRAM_RAS_N,
		zs_we_n			=> DRAM_WE_N 
		);
	
	-- Lettura e scrittura sul chip audio
	Audio_Controller_Entity: Audio_Controller port map (
		clk 						=> CLOCK_50, 
		reset 						=> reset or AudioInChanged, 
		clear_audio_in_memory 		=> '0', 
		read_audio_in 				=> read_audio_in, 
		clear_audio_out_memory		=> '0',
		left_channel_audio_out		=> audio_out & "0000000000000000", 
		right_channel_audio_out		=> audio_out & "0000000000000000",
		write_audio_out				=> write_audio_out,
		AUD_ADCDAT					=> AUD_ADCDAT, 
		AUD_BCLK					=> AUD_BCLK,
		AUD_ADCLRCK					=> AUD_ADCLRCK,
		AUD_DACLRCK					=> AUD_DACLRCK,
		I2C_SDAT					=> I2C_SDAT,
		audio_in_available			=> audio_in_available,
		left_channel_audio_in		=> left_channel_audio_in_sig,
		right_channel_audio_in		=> OPEN,
		audio_out_allowed			=> audio_out_allowed,
		AUD_XCK						=> OPEN,
		AUD_DACDAT					=> AUD_DACDAT,
		I2C_SCLK					=> I2C_SCLK,
		useMicInput					=> useMicInput
		);
	
	-- Gestisce registrazione su RAM e riproduzione da RM dell'audio
	PlayRecord_Entity: PlayRecord port map(
		CLOCK_50,
		CLOCK_1S,
		reset, 
		ram_addr,
		ram_data_in,
		ram_read,
		ram_write,
		ram_data_out,
		ram_valid,
		ram_waitrq,
		audio_out, 
		audio_in,
		audio_out_allowed,
		audio_in_available,
		write_audio_out,
		read_audio_in,
		play_Cmd,
		record_Cmd,
		pause_Cmd,
		speed,
		ram_addr_max,
		playLimitReached,
		secondsCounter
		);
	
	-- Inizializzazione adattatore monitor VGA
	VGA_Adapter_Entity: VGA_Adapter port map(
		NOT reset,
		CLOCK_50,
		VGA_CLK,
		vga_color,
		vga_x,
		vga_y,
		vga_plot,
		VGA_R,
		VGA_G,
		VGA_B,
		VGA_HS,
		VGA_VS,
		VGA_BLANK,
		VGA_SYNC
		);
	
	-- Modulo che gestisce il display su monitor VGA
	Display_Entity: Display port map(
		CLOCK_50,
		reset,
		pause_Cmd,
		display_data_scaled,
		vga_x,
		vga_y,
		vga_color,
		vga_plot
		);
	
	-- Convertitori da Binario a BCD
	SecondsCounter_Entity:	BinaryToBcd port map(secondsCounter, secondsCounter0, secondsCounter1, secondsCounter2);
	SecondsMax_Entity:		BinaryToBcd port map(seconds_max, seconds_max0, seconds_max1, seconds_max2);
	
	-- I display a 7 segmenti 0 e 1 sono usati per visualizzare l'indirizzo della RAM o dei secondi (in rec o play)
	h0_Entity: 				hex2seg port map(h0_sig, HEX0);	
	h1_Entity: 				hex2seg port map(h1_sig, HEX1);
		
	-- Il display a 7 segmenti 2 e' usato per visualizzare il fattore di scala dell'onda sul monitor VGA
	h4_Entity: 				hex2seg port map(h2_sig,HEX2);

	-- Il display a 7 segmenti 3 viene usato per visualizzare la velocita di riproduzione
	h3_Entity: 				hex2seg port map(h3_sig,HEX3);

end behaviour;
