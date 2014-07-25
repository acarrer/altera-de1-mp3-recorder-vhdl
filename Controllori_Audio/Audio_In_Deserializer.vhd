-- **********************************************************
--   Corso di Reti Logiche - Progetto Registratore Portatile
--   Andrea Carrer - 729101
--   Modulo Audio_In_Deserializer.vhd
--   Versione 1.01 - 14.03.2013
-- **********************************************************

-- **********************************************************
-- Lettura dati dall'ADC. I dati vengono ricevuti in seriale
-- e deserializzati, cioe' raggruppati in blocchi da 32 bit.
-- **********************************************************

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;

entity Audio_In_Deserializer is 
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

end Audio_In_Deserializer;

architecture behaviour of Audio_In_Deserializer is

	component Audio_Bit_Counter is
		generic(
			BIT_COUNTER_INIT: 				std_logic_vector(4 downto 0)  := "11111"
		);
		port(
			clk:							in std_logic;
			reset:							in std_logic;
			
			bit_clk_rising_edge:			in std_logic;
			bit_clk_falling_edge:			in std_logic;
			left_right_clk_rising_edge:		in std_logic;
			left_right_clk_falling_edge:	in std_logic;

			counting:						out std_logic
		);
	end component;
	
	component SYNC_FIFO is
		generic (
			DATA_WIDTH: integer := 32;
			DATA_DEPTH: integer := 128;
			ADDR_WIDTH: integer := 7
			);

		port (
			clk:			in std_logic;
			reset:			in std_logic;
			write_en:		in std_logic;
			write_data:		in std_logic_vector(DATA_WIDTH downto 1);
			read_en:		in std_logic;

			fifo_is_empty:	out std_logic;
			fifo_is_full:	out std_logic;
			words_used:		out std_logic_vector(ADDR_WIDTH downto 1);
			read_data:		out std_logic_vector(DATA_WIDTH downto 1)
		);
	end component;

	signal valid_audio_input:			std_logic;
	signal left_channel_fifo_is_empty:	std_logic;
	signal right_channel_fifo_is_empty:	std_logic;
	signal left_channel_fifo_is_full:	std_logic;
	signal right_channel_fifo_is_full:	std_logic;
	signal left_channel_fifo_used:		std_logic_vector(6 downto 0);
	signal right_channel_fifo_used:		std_logic_vector(6 downto 0);
	
	signal data_in_shift_reg:			std_logic_vector(AUDIO_DATA_WIDTH downto 1);

begin

	process(clk)
	begin
		if (rising_edge(clk)) then
			if (reset = '1') then
				left_audio_fifo_read_space				<= "00000000";
			else
				left_audio_fifo_read_space(7)			<= left_channel_fifo_is_full;
				left_audio_fifo_read_space(6 downto 0)	<= left_channel_fifo_used;
			end if;
		end if;
	end process;

	process(clk)
	begin
		if (rising_edge(clk)) then
			if (reset = '1') then
				right_audio_fifo_read_space				<= "00000000";
			else
				right_audio_fifo_read_space(7)			<= right_channel_fifo_is_full;
				right_audio_fifo_read_space(6 downto 0)	<= right_channel_fifo_used;
			end if;
		end if;
	end process;

	process(clk)
	begin
		if (rising_edge(clk)) then
			if (reset = '1') then
				data_in_shift_reg <= "00000000000000000000000000000000";
			elsif (bit_clk_rising_edge='1' and valid_audio_input='1') then
				data_in_shift_reg <= data_in_shift_reg((AUDIO_DATA_WIDTH - 1) downto 1) & serial_audio_in_data;
			end if;
		end if;
	end process;

	Audio_Out_Bit_Counter: Audio_Bit_Counter generic map (
			BIT_COUNTER_INIT	=> BIT_COUNTER_INIT
		)
		port map(
			clk							=> clk,
			reset						=> reset,
			bit_clk_rising_edge			=> bit_clk_rising_edge,
			bit_clk_falling_edge		=> bit_clk_falling_edge,
			left_right_clk_rising_edge	=> left_right_clk_rising_edge,
			left_right_clk_falling_edge	=> left_right_clk_falling_edge,
			counting					=> valid_audio_input
		);

	Audio_In_Left_Channel_FIFO: SYNC_FIFO generic map(
			DATA_WIDTH	=> AUDIO_DATA_WIDTH,
			DATA_DEPTH	=> 128,
			ADDR_WIDTH	=> 7
		)
		port map (
			clk				=> clk,
			reset			=> reset,
			write_en		=> left_right_clk_falling_edge and not left_channel_fifo_is_full and done_channel_sync,
			write_data		=> data_in_shift_reg,
			read_en			=> read_left_audio_data_en and not left_channel_fifo_is_empty,
			fifo_is_empty	=> left_channel_fifo_is_empty,
			fifo_is_full	=> left_channel_fifo_is_full,
			words_used		=> left_channel_fifo_used,
			read_data		=> left_channel_data
	);

	Audio_In_Right_Channel_FIFO: SYNC_FIFO generic map(
			DATA_WIDTH	=> AUDIO_DATA_WIDTH,
			DATA_DEPTH	=> 128,
			ADDR_WIDTH	=> 7
		)
		port map (
			clk				=> clk,
			reset			=> reset,
			write_en		=> left_right_clk_rising_edge and not right_channel_fifo_is_full and done_channel_sync,
			write_data		=> data_in_shift_reg,
			read_en			=> read_right_audio_data_en and not right_channel_fifo_is_empty,
			fifo_is_empty	=> right_channel_fifo_is_empty,
			fifo_is_full	=> right_channel_fifo_is_full,
			words_used		=> right_channel_fifo_used,
			read_data		=> right_channel_data
	);

end behaviour;