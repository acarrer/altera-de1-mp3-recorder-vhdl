-- **********************************************************
--   Corso di Reti Logiche - Progetto Registratore Portatile
--   Andrea Carrer - 729101
--   Modulo VGA_Adapter.vhd
--   Versione 1.01 - 14.03.2013
-- **********************************************************

-- **********************************************************
-- Modulo trovato in rete, convertito da Verilog a VHDL
-- e successivamente adattato al progetto.
-- Ho utilizzato la risoluzione 320x240 monocromatica.
-- Occupazione totale di memoria: 76800 bit.
-- **********************************************************

--VGA Adapter
------------------
--
--This is an implementation of a VGA Adapter. The adapter uses VGA mode signalling to initiate
--a 640x480 resolution mode on a computer monitor, with a refresh rate of approximately 60Hz.
--It is designed for easy use in an early digital logic design course to facilitate student
--projects on the Altera DE1 Educational board.
--
--This implementation of the VGA adapter can display images of varying colour depth at a resolution of
--320x240 or 160x120 superpixels. The concept of superpixels is introduced to reduce the amount of on-chip
--memory used by the adapter. The following table shows the number of bits of on-chip memory used by
--the adapter in various resolutions and colour depths.
--
---------------------------------------------------------------------------------------------------------------------------------
--Resolution | Mono    | 8 colours | 64 colours | 512 colours | 4096 colours | 32768 colours | 262144 colours | 2097152 colours |
---------------------------------------------------------------------------------------------------------------------------------
--160x120    |   19200 |     57600 |     115200 |      172800 |       230400 |        288000 |         345600 |          403200 |
--320x240    |   78600 |    230400 | ############## Does not fit ############################################################## |
---------------------------------------------------------------------------------------------------------------------------------
--
--By default the adapter works at the resolution of 320x240 with 8 colours. To set the adapter in any of
--the other modes, the adapter must be instantiated with specific parameters. These parameters are:
--- RESOLUTION - a string that should be either "320x240" or "160x120".
--- MONOCHROME - a string that should be "TRUE" if you only want black and white colours, and "FALSE"
--               otherwise.
--- BITS_PER_COLOUR_CHANNEL  - an integer specifying how many bits are available to describe each colour
--                         (R,G,B). A default value of 1 indicates that 1 bit will be used for red
--                         channel, 1 for green channel and 1 for blue channel. This allows 8 colours
--                         to be used.
--
--In addition to the above parameters, a BACKGROUND_IMAGE parameter can be specified. The parameter
--refers to a memory initilization file (MIF) which contains the initial contents of video memory.
--By specifying the initial contents of the memory we can force the adapter to initially display an
--image of our choice. Please note that the image described by the BACKGROUND_IMAGE file will only
--be valid right after your program the DE2 board. If your circuit draws a single pixel on the screen,
--the video memory will be altered and screen contents will be changed. In order to restore the background
--image your circuti will have to redraw the background image pixel by pixel, or you will have to
--reprogram the DE2 board, thus allowing the video memory to be rewritten.
--
--To use the module connect the vga_adapter to your circuit. Your circuit should produce a value for
--inputs X, Y and plot. When plot is high, at the next positive edge of the input clock the vga_adapter
--will change the contents of the video memory for the pixel at location (X,Y). At the next redraw
--cycle the VGA controller will update the contants of the screen by reading the video memory and copying
--it over to the screen. Since the monitor screen has no memory, the VGA controller has to copy the
--contents of the video memory to the screen once every 60th of a second to keep the image stable. Thus,
--the video memory should not be used for other purposes as it may interfere with the operation of the
--VGA Adapter.
--
--As a final note, ensure that the following conditions are met when using this module:
--1. You are implementing the the VGA Adapter on the Altera DE2 board. Using another board may change
--   the amount of memory you can use, the clock generation mechanism, as well as pin assignments required
--   to properly drive the VGA digital-to-analog converter.
--2. Outputs VGA_* should exist in your top level design. They should be assigned pin locations on the
--   Altera DE2 board as specified by the DE2_pin_assignments.csv file.
--3. The input clock must have a frequency of 50 MHz with a 50% duty cycle. On the Altera DE2 board
--   PIN_N2 is the source for the 50MHz clock.
--
--During compilation with Quartus II you may receive the following warnings:
--- Warning: Variable or input pin "clocken1" is defined but never used
--- Warning: Pin "VGA_SYNC" stuck at VCC
--- Warning: Found xx output pins without output pin load capacitance assignment
--These warnings can be ignored. The first warning is generated, because the software generated
--memory module contains an input called "clocken1" and it does not drive logic. The second warning
--indicates that the VGA_SYNC signal is always high. This is intentional. The final warning is
--generated for the purposes of power analysis. It will persist unless the output pins are assigned
--output capacitance. Leaving the capacitance values at 0 pf did not affect the operation of the module.
--
--If you see any other warnings relating to the vga_adapter, be sure to examine them carefully. They may
--cause your circuit to malfunction.

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;
library Altera_mf;
	use altera_mf.altera_mf_components.all;

entity VGA_Adapter is port(
	resetn:		in std_logic;
	clock:		in std_logic;
	clock_25:	in std_logic;
	colour:		in std_logic;
	x:			in std_logic_vector(8 downto 0);	-- Coordinata x
	y:			in std_logic_vector(7 downto 0);	-- Coordinata y
	plot:		in std_logic;						-- Quando e'=1, il pixel (x,y) cambierà' colore (bisogna plottare)
													-- Segnali per il DAC per pilotare il monitor.
	VGA_R:		out std_logic_vector(9 downto 0);
	VGA_G:		out std_logic_vector(9 downto 0);
	VGA_B:		out std_logic_vector(9 downto 0);
	VGA_HS:		out std_logic;
	VGA_VS:		out std_logic;
	VGA_BLANK:	out std_logic;
	VGA_SYNC:	out std_logic
	);
end VGA_Adapter;

architecture behaviour of VGA_Adapter is

	component VGA_CalcoloIndirizzo is port (
		x            : in std_logic_vector(8 downto 0);
		y            : in std_logic_vector(7 downto 0);
		mem_address  : out std_logic_vector(16 downto 0)
		);
	end component;
	
	component VGA_Controller is port(	
		vga_clock:			in std_logic;
		resetn:				in std_logic;
		pixel_colour:		in std_logic_vector(0 downto 0);
		memory_address:		out std_logic_vector(16 downto 0);
		VGA_R:				out std_logic_vector(9 downto 0) register;
		VGA_G:				out std_logic_vector(9 downto 0) register;
		VGA_B:				out std_logic_vector(9 downto 0) register;
		VGA_HS:				out std_logic register;
		VGA_VS:				out std_logic register;
		VGA_BLANK:			out std_logic register;
		VGA_SYNC:			out std_logic	-- VGA sync e' sempre a 1.
		);
	end component;
	
	signal valid_320x240: 					std_logic;		-- Serve a specificare che le coordinate siano in un range valido.
	signal writeEn:							std_logic;		-- Serve ad abilitare la scrittura della memoria video d un certo pixcel (x,y)
	signal to_ctrl_colour:					std_logic;		-- Pixel letto dal controller VGA
	signal user_to_video_memory_addr: 		std_logic_vector(16 downto 0); -- Indirizzo di memoria per scrivere le coordnate (x,y)
	signal controller_to_video_memory_addr: std_logic_vector(16 downto 0); -- Indirizzo di memoria per leggere le coordnate (x,y)
	signal vcc:								std_logic := '1';				-- Serve al VGA Adapter
	signal gnd:								std_logic := '0';				-- Serve al VGA Adapter

begin

	-- Controllo validita' coordinate
	valid_320x240 <= '1' when (
		(x >= "000000000")
		and (x < "101000000")		-- x < 320
		and (y >= "00000000")
		and (y < "11110000"));		-- y < 240
	
	-- Controllo abilitazione scrittura
	writeEn <= '1' when (plot='1') and (valid_320x240='1') else '0';
	
	-- Converte le coordinate in un indirizzo di memoria
	CoordinatesTranslator : VGA_CalcoloIndirizzo port map(
			x => x,
			y => y,
			mem_address => user_to_video_memory_addr
			);	
	
	-- Allocazione memoria video
	VideoMemory : altsyncram
		generic map (
			WIDTH_A 					=> 1,
			WIDTH_B 					=> 1,
			INTENDED_DEVICE_FAMILY 		=> "Cyclone II",
			OPERATION_MODE 				=> "DUAL_PORT",
			WIDTHAD_A 					=> 17,
			NUMWORDS_A 					=> 76800,
			WIDTHAD_B 					=> 17,
			NUMWORDS_B 					=> 76800,
			OUTDATA_REG_B 				=> "CLOCK1",
			ADDRESS_REG_B 				=> "CLOCK1",
			CLOCK_ENABLE_INPUT_A 		=> "BYPASS",
			CLOCK_ENABLE_INPUT_B 		=> "BYPASS",
			CLOCK_ENABLE_OUTPUT_B 		=> "BYPASS",
			POWER_UP_UNINITIALIZED 		=> "FALSE"
		)
		port map (
			wren_a 		=> writeEn,
			wren_b 		=> gnd,
			clock0 		=> clock, 							-- write clock
			clock1 		=> clock_25, 						-- read clock
			clocken0 	=> vcc, 							-- write enable clock
			clocken1 	=> vcc, 							-- read enable clock				
			address_a 	=> user_to_video_memory_addr,
			address_b 	=> controller_to_video_memory_addr,
			data_a(0) 	=> colour, 							-- data in
			q_b(0) 		=> to_ctrl_colour					-- data out
		);
		
	-- Istanza del controller VGA
	VGAcontroller : VGA_Controller port map (
			vga_clock => clock_25,
			resetn => resetn,
			pixel_colour(0) => to_ctrl_colour,
			memory_address => controller_to_video_memory_addr, 
			VGA_R => VGA_R,
			VGA_G => VGA_G,
			VGA_B => VGA_B,
			VGA_HS => VGA_HS,
			VGA_VS => VGA_VS,
			VGA_BLANK => VGA_BLANK,
			VGA_SYNC => VGA_SYNC
		);
end behaviour;	