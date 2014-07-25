-- **********************************************************
--   Corso di Reti Logiche - Progetto Registratore Portatile
--   Andrea Carrer - 729101
--   Modulo Audio_Controller.vhd
--   Versione 1.01 - 14.03.2013
-- **********************************************************

-- **********************************************************
-- Modulo che legge e scrive i dati dal WM8731.
-- Utilizza il master mode e la giustificazione a sinistra.
-- **********************************************************

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;

entity Audio_Controller is 
	generic (
		AUDIO_DATA_WIDTH: integer 						:= 32;
		BIT_COUNTER_INIT: std_logic_vector(4 downto 0)	:= "11111"
	);
	port (
		clear_audio_out_memory:		in std_logic;
		reset:						in std_logic;
		clear_audio_in_memory:		in std_logic;
		read_audio_in:				in std_logic;
		clk:						in std_logic;
		left_channel_audio_out:		in std_logic_vector(AUDIO_DATA_WIDTH downto 1);
		right_channel_audio_out:	in std_logic_vector(AUDIO_DATA_WIDTH downto 1);
		write_audio_out:			in std_logic;
		AUD_ADCDAT:					in std_logic;
		AUD_BCLK:					inout std_logic;
		AUD_ADCLRCK:				inout std_logic;
		AUD_DACLRCK:				inout std_logic;
		I2C_SDAT:					inout std_logic;
		audio_in_available:			buffer std_logic; --out std_logic;
		left_channel_audio_in:		out std_logic_vector(AUDIO_DATA_WIDTH downto 1);
		right_channel_audio_in:		out std_logic_vector(AUDIO_DATA_WIDTH downto 1);
		audio_out_allowed:			buffer std_logic; --out std_logic;
		AUD_XCK:					out std_logic;
		AUD_DACDAT:					out std_logic;
		I2C_SCLK:					out std_logic;
		useMicInput:				in std_logic
	);
end Audio_Controller;

architecture behaviour of Audio_Controller is

	component Clock_Edge is port (
		clk:			in std_logic;
		reset:			in std_logic;
		test_clk:		in std_logic;
		ris_edge:		out std_logic;
		fal_edge:		out std_logic
	);

	end component;

	component Audio_In_Deserializer is 
		generic (
			AUDIO_DATA_WIDTH:	integer := 32;
			BIT_COUNTER_INIT:	std_logic_vector (4 downto 0) := "11111"
		);
		port (	
			clk:							in std_logic;
			reset:							in std_logic;
			bit_clk_rising_edge:			in std_logic;
			bit_clk_falling_edge:			in std_logic;
			left_right_clk_rising_edge:		in std_logic;
			left_right_clk_falling_edge:	in std_logic;
			done_channel_sync:				in std_logic;
			serial_audio_in_data:			in std_logic;
			read_left_audio_data_en:		in std_logic;
			read_right_audio_data_en:		in std_logic;
			left_audio_fifo_read_space:		out std_logic_vector(7 downto 0);
			right_audio_fifo_read_space:	out std_logic_vector(7 downto 0);
			left_channel_data:				out std_logic_vector(AUDIO_DATA_WIDTH downto 1);
			right_channel_data:				out std_logic_vector(AUDIO_DATA_WIDTH downto 1)
		);
	
	end component;
	
	component Audio_Out_Serializer is
		generic (
			AUDIO_DATA_WIDTH: 				integer	:= 32
		);
		port (
			clk:							in std_logic;
			reset:							in std_logic;
			bit_clk_rising_edge:			in std_logic;
			bit_clk_falling_edge:			in std_logic;
			left_right_clk_rising_edge:		in std_logic;
			left_right_clk_falling_edge:	in std_logic;
			left_channel_data:				in std_logic_vector(AUDIO_DATA_WIDTH downto 1);
			left_channel_data_en:			in std_logic;
			right_channel_data:				in std_logic_vector(AUDIO_DATA_WIDTH downto 1);
			right_channel_data_en:			in std_logic;
			left_channel_fifo_write_space:	out std_logic_vector(7 downto 0);
			right_channel_fifo_write_space:	out std_logic_vector(7 downto 0);
			serial_audio_out_data:			out std_logic
		);
	
	end component;
	
	component AudioVideo_Config is port(
		clk:			in std_logic;
		reset:			in std_logic;
		ob_address:		in std_logic_vector(2 downto 0);
		ob_byteenable:	in std_logic_vector(3 downto 0);
		ob_chipselect:	in std_logic;
		ob_read:		in std_logic;
		ob_write:		in std_logic;
		ob_writedata:	in std_logic_vector(31 downto 0);

		I2C_SDAT:		inout std_logic;

		ob_readdata:	out std_logic_vector(31 downto 0);
		ob_waitrequest:	out std_logic;
		I2C_SCLK:		out std_logic;
		
		useMicInput:	in std_logic
		);

	end component;

	signal bclk_rising_edge:			std_logic;
	signal bclk_falling_edge:			std_logic;
	signal adc_lrclk_rising_edge:		std_logic;
	signal adc_lrclk_falling_edge:		std_logic;
	signal dac_lrclk_rising_edge:		std_logic;
	signal dac_lrclk_falling_edge:		std_logic;
	
	signal left_channel_read_available:	std_logic_vector(7 downto 0);
	signal right_channel_read_available:std_logic_vector(7 downto 0);
	signal left_channel_write_space:	std_logic_vector(7 downto 0);
	signal right_channel_write_space:	std_logic_vector(7 downto 0);

	signal done_adc_channel_sync:		std_logic;
	signal done_dac_channel_sync:		std_logic;

begin

	AUD_BCLK	<= 'Z';
	AUD_ADCLRCK	<= 'Z';
	AUD_DACLRCK	<= 'Z';

	process (clk)
	begin
		if reset = '1' then
			audio_in_available <= '0';
		elsif ((left_channel_read_available(7)='1' or left_channel_read_available(6)='1')
				and (right_channel_read_available(7)='1' or right_channel_read_available(6)='1')) then
			audio_in_available <= '1';
		else
			audio_in_available <= '0';
		end if;
	end process;

	process (clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then
				audio_out_allowed <= '0';
			elsif ((left_channel_write_space(7)='1' or left_channel_write_space(6)='1')
					and (right_channel_write_space(7)='1' or right_channel_write_space(6)='1')) then
				audio_out_allowed <= '1';
			else
				audio_out_allowed <= '0';
			end if;
		end if;
	end process;

	process (clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then
				done_adc_channel_sync <= '0';
			elsif (adc_lrclk_rising_edge = '1') then
				done_adc_channel_sync <= '1';
			end if;
		end if;
	end process;

	process (clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then
				done_dac_channel_sync <= '0';
			elsif (dac_lrclk_falling_edge = '1') then
				done_dac_channel_sync <= '1';
			end if;
		end if;
	end process;

	Bit_Clock_Edges: Clock_Edge port map (
		clk			=> clk,
		reset		=> reset,
		test_clk	=> AUD_BCLK,
		ris_edge	=> bclk_rising_edge,
		fal_edge	=> bclk_falling_edge
	);

	ADC_Left_Right_Clock_Edges: Clock_Edge port map (
		clk			=> clk,
		reset		=> reset,
		test_clk	=> AUD_ADCLRCK,
		ris_edge	=> adc_lrclk_rising_edge,
		fal_edge	=> adc_lrclk_falling_edge
	);

	DAC_Left_Right_Clock_Edges: Clock_Edge port map (
		clk			=> clk,
		reset		=> reset,
		test_clk	=> AUD_DACLRCK,
		ris_edge	=> dac_lrclk_rising_edge,
		fal_edge	=> dac_lrclk_falling_edge
	);

	Audio_In_Deserializer_Entity: Audio_In_Deserializer generic map (
		AUDIO_DATA_WIDTH 			=> AUDIO_DATA_WIDTH,
		BIT_COUNTER_INIT 			=> BIT_COUNTER_INIT
		) port map (
		clk							=> clk,
		reset						=> reset or clear_audio_in_memory,
		bit_clk_rising_edge			=> bclk_rising_edge,
		bit_clk_falling_edge		=> bclk_falling_edge,
		left_right_clk_rising_edge	=> adc_lrclk_rising_edge,
		left_right_clk_falling_edge	=> adc_lrclk_falling_edge,
		done_channel_sync			=> done_adc_channel_sync,
		serial_audio_in_data		=> AUD_ADCDAT,
		read_left_audio_data_en		=> read_audio_in and audio_in_available,
		read_right_audio_data_en	=> read_audio_in and audio_in_available,
		left_audio_fifo_read_space	=> left_channel_read_available,
		right_audio_fifo_read_space	=> right_channel_read_available,
		left_channel_data			=> left_channel_audio_in,
		right_channel_data			=> right_channel_audio_in
	);

	Audio_Out_Serializer_Entity: Audio_Out_Serializer generic map (
		AUDIO_DATA_WIDTH 				=> AUDIO_DATA_WIDTH
		) port map (
		clk								=> clk,
		reset							=> reset or clear_audio_out_memory,
		bit_clk_rising_edge				=> bclk_rising_edge,
		bit_clk_falling_edge			=> bclk_falling_edge,
		left_right_clk_rising_edge		=> done_dac_channel_sync and dac_lrclk_rising_edge,
		left_right_clk_falling_edge		=> done_dac_channel_sync and dac_lrclk_falling_edge,
		left_channel_data				=> left_channel_audio_out,
		left_channel_data_en			=> write_audio_out and audio_out_allowed,
		right_channel_data				=> right_channel_audio_out,
		right_channel_data_en			=> write_audio_out and audio_out_allowed,
		left_channel_fifo_write_space	=> left_channel_write_space,
		right_channel_fifo_write_space	=> right_channel_write_space,
		serial_audio_out_data			=> AUD_DACDAT
	);

	AudioVideo_Config_Entity: AudioVideo_Config port map (
		clk				=> clk,
		reset			=> reset,
		ob_address		=> "ZZZ",
		ob_byteenable	=> "ZZZZ",
		ob_chipselect	=> 'Z',
		ob_read			=> 'Z',
		ob_write		=> 'Z',
		ob_writedata	=> "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ",
		I2C_SDAT		=> I2C_SDAT,
		ob_readdata		=> OPEN,
		ob_waitrequest	=> OPEN,
		I2C_SCLK		=> I2C_SCLK,
		useMicInput		=> useMicInput
	);

end behaviour;