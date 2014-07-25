-- **********************************************************
--   Corso di Reti Logiche - Progetto Registratore Portatile
--   Andrea Carrer - 729101
--   Modulo VGA_Controller.vhd
--   Versione 1.01 - 14.03.2013
-- **********************************************************

-- **********************************************************
-- Modulo trovato in rete, convertito da Verilog a VHDL
-- e successivamente adattato al progetto. 
-- Implementazione del controller VGA.
-- **********************************************************

-- This module implements the VGA controller. It assumes a 25MHz clock is supplied as input.
--
-- General approach:
-- Go through each line of the screen and read the colour each pixel on that line should have from
-- the Video memory. To do that for each (x,y) pixel on the screen convert (x,y) coordinate to
-- a memory_address at which the pixel colour is stored in Video memory. Once the pixel colour is
-- read from video memory its brightness is first increased before it is forwarded to the VGA DAC.

library ieee;
   use ieee.std_logic_1164.all;
   use ieee.std_logic_unsigned.all;

entity VGA_Controller 
	is generic(
		-- Timing parameters.
		-- Recall that the VGA specification requires a few more rows and columns are drawn
		-- when refreshing the screen than are actually present on the screen. This is necessary to
		-- generate the vertical and the horizontal syncronization signals. If you wish to use a
		-- display mode other than 640x480 you will need to modify the parameters below as well
		-- as change the frequency of the clock driving the monitor (VGA_CLK).

		C_VERT_NUM_PIXELS: 	std_logic_vector(9 downto 0)  := "0111100000"; -- 480
		C_VERT_SYNC_START: 	std_logic_vector(9 downto 0)  := "0111101101"; -- 493
		C_VERT_SYNC_END: 	std_logic_vector(9 downto 0)  := "0111101110"; -- 494
		C_VERT_TOTAL_COUNT: std_logic_vector(9 downto 0)  := "1000001101"; -- 525

		C_HORZ_NUM_PIXELS: 	std_logic_vector(9 downto 0)  := "1010000000"; -- 640
		C_HORZ_SYNC_START: 	std_logic_vector(9 downto 0)  := "1010010011"; -- 659
		C_HORZ_SYNC_END: 	std_logic_vector(9 downto 0)  := "1011110010"; -- 754 (C_HORZ_SYNC_START + 96 - 1); 
		C_HORZ_TOTAL_COUNT: std_logic_vector(9 downto 0)  := "1100100000"  -- 800;	
	);
	
	port(	
		vga_clock:			in std_logic;
		resetn:				in std_logic;
		pixel_colour:		in std_logic_vector(0 downto 0);
		memory_address:		out std_logic_vector(16 downto 0);
		VGA_R:				out std_logic_vector(9 downto 0);
		VGA_G:				out std_logic_vector(9 downto 0);
		VGA_B:				out std_logic_vector(9 downto 0);
		VGA_HS:				out std_logic register;
		VGA_VS:				out std_logic register;
		VGA_BLANK:			out std_logic register;
		VGA_SYNC:			out std_logic := '1'	-- VGA sync e' sempre a 1.
	);
	
end VGA_Controller;
	
architecture behaviour of VGA_Controller is
	
	component VGA_CalcoloIndirizzo is port (
		x            : in std_logic_vector(8 downto 0);
		y            : in std_logic_vector(7 downto 0);
		mem_address  : out std_logic_vector(16 downto 0)
		);
	end component;
		
	signal VGA_HS1:			std_logic register;
	signal VGA_VS1:			std_logic register;
	signal VGA_BLANK1:		std_logic register;
	
	signal xCounter:		std_logic_vector(9 downto 0) register;
	signal yCounter:		std_logic_vector(8 downto 0) register;
	
	signal xCounter_clear:	std_logic;
	signal yCounter_clear:	std_logic;

	signal x:				std_logic_vector(8 downto 0);
	signal y:				std_logic_vector(7 downto 0);
	
	signal VGA_HS1_sig:		std_logic;
	signal VGA_VS1_sig:		std_logic;
		
	signal VGA_BLANK1_sig:	std_logic;	
	
	begin

	xCounter_clear <= '1' when (xCounter = (C_HORZ_TOTAL_COUNT-1)) else '0';
	yCounter_clear <= '1' when (yCounter = (C_VERT_TOTAL_COUNT-1)) else '0';
		
	VGA_HS1_sig <= '1' when (not((xCounter >= C_HORZ_SYNC_START) and (xCounter <= C_HORZ_SYNC_END))) else '0';
	VGA_VS1_sig <= '1' when (not((yCounter >= C_VERT_SYNC_START) and (yCounter <= C_VERT_SYNC_END))) else '0';

	-- Current X and Y is valid pixel range
	VGA_BLANK1_sig <= '1' when (((xCounter < C_HORZ_NUM_PIXELS) and (yCounter < C_VERT_NUM_PIXELS))) else '0';	
	
	-- A counter to scan through a horizontal line.
	process
	begin
		wait until rising_edge(vga_clock);
		if (resetn ='0') then
			xCounter <= "0000000000";
		elsif (xCounter_clear ='1') then
			xCounter <= "0000000000";
		else
			xCounter <= xCounter + "0000000001";
		end if;
	end process;
	
	-- A counter to scan vertically, indicating the row currently being drawn.
	process
	begin
		wait until rising_edge(vga_clock);
		if (resetn ='0') then
			yCounter <= "000000000";
		elsif (xCounter_clear ='1' and yCounter_clear ='1') then
			yCounter <= "000000000";
		elsif (xCounter_clear = '1') then		--Increment when x counter resets
			yCounter <= yCounter + "000000001";
		end if;
	end	process;
	
	-- Generate the vertical and horizontal synchronization pulses.
	process (vga_clock)
	begin
		if rising_edge(vga_clock) then
			-- Sync Generator (ACTIVE LOW)
			VGA_HS1 <= VGA_HS1_sig;
			VGA_VS1 <= VGA_VS1_sig;
			
			-- Current X and Y is valid pixel range
			VGA_BLANK1 <= VGA_BLANK1_sig;	
		
			-- Add 1 cycle delay
			VGA_HS <= VGA_HS1;
			VGA_VS <= VGA_VS1;
			VGA_BLANK <= VGA_BLANK1;
		end if;
	end process;
		
	-- Convert the xCounter/yCounter location from screen pixels (640x480) to our
	-- local dots (320x240). Here we effectively divide x/y coordinate by 2,
	-- depending on the resolution.
	process (vga_clock, resetn, pixel_colour)
	begin
		x <= xCounter(9 downto 1);
		y <= yCounter(8 downto 1);
	end process;
	
	-- Brighten the colour output.
	-- The colour input is first processed to brighten the image a little. Setting the top
	-- bits to correspond to the R,G,B colour makes the image a bit dull.
	process (pixel_colour)
	begin
		VGA_R <= "0000000000";
		VGA_G <= "0000000000";
		VGA_B <= "0000000000";
		
		for index in 0 to 9 loop
			VGA_R(index) <= pixel_colour(0);
			VGA_G(index) <= pixel_colour(0);
			VGA_B(index) <= pixel_colour(0);
		end loop;
	end process;
	
	-- Conversione da coordinate (x,y) ad indirizzo di memoria.
	controller_translator : VGA_CalcoloIndirizzo
		port map(
			x => x,
			y => y,
			mem_address => memory_address);	
	
end behaviour;