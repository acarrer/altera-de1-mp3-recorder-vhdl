-- **********************************************************
--   Corso di Reti Logiche - Progetto Registratore Portatile
--   Andrea Carrer - 729101
--   Modulo Audio_Out_Serializer.vhd
--   Versione 1.01 - 14.03.2013
-- **********************************************************

-- **********************************************************
-- Scrittura dati provenienti dalla SDRAM sul bus dell'DAC.
-- Questi dati verranno convertiti in segnale analogico
-- dal DAC del chip WM8731.
-- **********************************************************

library ieee;
   USE ieee.std_logic_1164.all;
   USE ieee.std_logic_unsigned.all;

entity Audio_Out_Serializer is
	generic (
		AUDIO_DATA_WIDTH:				integer := 32
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

end Audio_Out_Serializer;

architecture behaviour of Audio_Out_Serializer is

	component SYNC_FIFO is
		generic (
			DATA_WIDTH: 	integer := 32;
			DATA_DEPTH: 	integer := 128;
			ADDR_WIDTH: 	integer := 7
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

	signal read_left_channel:				std_logic;
	signal read_right_channel:				std_logic;
	signal left_channel_fifo_is_empty:		std_logic;
	signal right_channel_fifo_is_empty:		std_logic;
	signal left_channel_fifo_is_full:		std_logic;
	signal right_channel_fifo_is_full:		std_logic;
	signal left_channel_fifo_used:			std_logic_vector(6 downto 0);
	signal right_channel_fifo_used:			std_logic_vector(6 downto 0);
	signal left_channel_from_fifo:			std_logic_vector(AUDIO_DATA_WIDTH downto 1);
	signal right_channel_from_fifo:			std_logic_vector(AUDIO_DATA_WIDTH downto 1);
	signal left_channel_was_read:			std_logic;
	signal data_out_shift_reg:				std_logic_vector(AUDIO_DATA_WIDTH downto 1);

begin
			
	process(clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				left_channel_fifo_write_space <= "00000000";
			else
				left_channel_fifo_write_space <= "10000000" - (left_channel_fifo_is_full & left_channel_fifo_used);
			end if;
		end if;
	end process;

	process(clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				right_channel_fifo_write_space <= "00000000";
			else
				right_channel_fifo_write_space <= "10000000" - (right_channel_fifo_is_full & right_channel_fifo_used);
			end if;
		end if;
	end process;

	process(clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				serial_audio_out_data <= '0';
			else
				serial_audio_out_data <= data_out_shift_reg(AUDIO_DATA_WIDTH);
			end if;
		end if;
	end process;

	process(clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				left_channel_was_read <= '0';
			elsif (read_left_channel='1') then
				left_channel_was_read <= '1';
			elsif (read_right_channel='1') then
				left_channel_was_read <= '0';
			end if;
		end if;
	end process;

	process(clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				data_out_shift_reg	<= "00000000000000000000000000000000"; -- {AUDIO_DATA_WIDTH{1'b0}};
			elsif (read_left_channel='1') then
				data_out_shift_reg	<= left_channel_from_fifo;
			elsif (read_right_channel='1') then
				data_out_shift_reg	<= right_channel_from_fifo;
			elsif (left_right_clk_rising_edge='1' or left_right_clk_falling_edge='1') then
				data_out_shift_reg	<= "00000000000000000000000000000000"; -- {AUDIO_DATA_WIDTH{1'b0}};
			elsif (bit_clk_falling_edge='1') then
				data_out_shift_reg	<= data_out_shift_reg((AUDIO_DATA_WIDTH - 1) downto 1) & '0';
			end if;
		end if;
	end process;

	read_left_channel	<= left_right_clk_rising_edge and not(left_channel_fifo_is_empty) and not(right_channel_fifo_is_empty);
	read_right_channel	<= left_right_clk_falling_edge and left_channel_was_read;

	Audio_Out_Left_Channel_FIFO: SYNC_FIFO generic map (
			DATA_WIDTH		=> AUDIO_DATA_WIDTH,
			DATA_DEPTH		=> 128,
			ADDR_WIDTH		=> 7
		)
		port map (
			clk				=> clk,
			reset			=> reset,
			write_en		=> left_channel_data_en and not(left_channel_fifo_is_full),
			write_data		=> left_channel_data,
			read_en			=> read_left_channel,
			fifo_is_empty	=> left_channel_fifo_is_empty,
			fifo_is_full	=> left_channel_fifo_is_full,
			words_used		=> left_channel_fifo_used,
			read_data		=> left_channel_from_fifo
		);

	Audio_Out_Right_Channel_FIFO: SYNC_FIFO generic map (
			DATA_WIDTH		=> AUDIO_DATA_WIDTH,
			DATA_DEPTH		=> 128,
			ADDR_WIDTH		=> 7
		)
		port map (
			clk				=> clk,
			reset			=> reset,
			write_en		=> right_channel_data_en and not (right_channel_fifo_is_full),
			write_data		=> right_channel_data,
			read_en			=> read_right_channel,
			fifo_is_empty	=> right_channel_fifo_is_empty,
			fifo_is_full	=> right_channel_fifo_is_full,
			words_used		=> right_channel_fifo_used,
			read_data		=> right_channel_from_fifo
		);
end behaviour;