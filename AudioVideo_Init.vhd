-- **********************************************************
--   Corso di Reti Logiche - Progetto Registratore Portatile
--   Andrea Carrer - 729101
--   Modulo AudioVideo_Init.vhd
--   Versione 1.02 - 18.03.2013
-- **********************************************************

-- **********************************************************
-- Questo modulo si occupa del caricamento dati sui
-- registri di controllo Audio/Video della scheda dopo ogni
-- reset del sistema.
-- **********************************************************

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;
	use ieee.std_logic_arith.all;

entity AudioVideo_Init is generic (
		MIN_ROM_ADDRESS:		std_logic_vector(5 downto 0) 	:= "000000"; 	--6'h00;
		MAX_ROM_ADDRESS:		std_logic_vector(5 downto 0) 	:= "001010"; 	--6'h0A;
		AUD_LINE_IN_LC:			std_logic_vector(8 downto 0) 	:= "000011000"; --9'd24;
		AUD_LINE_IN_RC:			std_logic_vector(8 downto 0) 	:= "000011000"; --9'd24;
		AUD_LINE_OUT_LC:		std_logic_vector(8 downto 0) 	:= "001110111";	--9'd119;
		AUD_LINE_OUT_RC:		std_logic_vector(8 downto 0) 	:= "001110111";	--9'd119;
		AUD_ADC_PATH:			std_logic_vector(8 downto 0) 	:= "000010001"; --9'd17;
		AUD_DAC_PATH:			std_logic_vector(8 downto 0) 	:= "000000110"; --9'd6;
		AUD_POWER:				std_logic_vector(8 downto 0) 	:= "000000000"; --9'h000;
		AUD_DATA_FORMAT:		std_logic_vector(8 downto 0) 	:= "001001101"; --9'd77;
		AUD_SAMPLE_CTRL:		std_logic_vector(8 downto 0) 	:= "000000000"; --9'd0;
		AUD_SET_ACTIVE:			std_logic_vector(8 downto 0) 	:= "000000001"  --9'h001;
	);
	port (
		clk:				in std_logic;
		reset:				in std_logic;
		clear_error:		in std_logic;
		ack:				in std_logic;
		transfer_complete:	in std_logic;

		data_out:			out std_logic_vector(7 downto 0);
		transfer_data:		buffer std_logic;
		send_start_bit:		out std_logic;
		send_stop_bit:		out std_logic;
		auto_init_complete:	out std_logic;
		auto_init_error:	out std_logic;

		useMicInput:		in std_logic
	);
end AudioVideo_Init;

architecture behaviour of AudioVideo_Init is

	-- Definizione stati della FSM per l'inizializzazione
	constant AUTO_STATE_0_CHECK_STATUS:		std_logic_vector(2 downto 0) := "000";
	constant AUTO_STATE_1_SEND_START_BIT:	std_logic_vector(2 downto 0) := "001";
	constant AUTO_STATE_2_TRANSFER_BYTE_1:	std_logic_vector(2 downto 0) := "010";
	constant AUTO_STATE_3_TRANSFER_BYTE_2:	std_logic_vector(2 downto 0) := "011";
	constant AUTO_STATE_4_WAIT:				std_logic_vector(2 downto 0) := "100";
	constant AUTO_STATE_5_SEND_STOP_BIT:	std_logic_vector(2 downto 0) := "101";
	constant AUTO_STATE_6_INCREASE_COUNTER:	std_logic_vector(2 downto 0) := "110";
	constant AUTO_STATE_7_DONE:				std_logic_vector(2 downto 0) := "111";

	signal change_state:		std_logic;
	signal finished_auto_init:	std_logic;

	signal rom_address_counter:	std_logic_vector(5 downto 0);
	signal rom_data:			std_logic_vector(25 downto 0);

	signal ns_i2c_auto_init:	std_logic_vector(2 downto 0);
	signal s_i2c_auto_init:		std_logic_vector(2 downto 0);
	
	-- Segnale di buffer
	signal rom_data_buff:		std_logic_vector(27 downto 0);

begin

	rom_data <= rom_data_buff(25 downto 0);

	auto_init_complete	<= '1' when (s_i2c_auto_init = AUTO_STATE_7_DONE) else '0';
	change_state		<= transfer_complete and transfer_data;
	finished_auto_init 	<= '1' when (rom_address_counter = MAX_ROM_ADDRESS) else '0';

	process (clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				s_i2c_auto_init <= AUTO_STATE_0_CHECK_STATUS;
			else
				s_i2c_auto_init <= ns_i2c_auto_init;
			end if;
		end if;
	end process;

	process (all)			
	begin
		ns_i2c_auto_init <= AUTO_STATE_0_CHECK_STATUS;
		
		---------------------------------------------------------------------------------------------
		------------------------------------------------------------------ FSM Inizializzazione Audio
 		---------------------------------------------------------------------------------------------

		if (s_i2c_auto_init = AUTO_STATE_0_CHECK_STATUS) then
			if (finished_auto_init = '1') then
				ns_i2c_auto_init <= AUTO_STATE_7_DONE;
			elsif (rom_data(25) = '1') then
				ns_i2c_auto_init <= AUTO_STATE_1_SEND_START_BIT;
			else
				ns_i2c_auto_init <= AUTO_STATE_3_TRANSFER_BYTE_2;
			end if;
		elsif (s_i2c_auto_init = AUTO_STATE_1_SEND_START_BIT) then
			if (change_state = '1') then
				ns_i2c_auto_init <= AUTO_STATE_2_TRANSFER_BYTE_1;
			else
				ns_i2c_auto_init <= AUTO_STATE_1_SEND_START_BIT;
			end if;
		elsif (s_i2c_auto_init = AUTO_STATE_2_TRANSFER_BYTE_1) then
			if (change_state = '1') then
				ns_i2c_auto_init <= AUTO_STATE_3_TRANSFER_BYTE_2;
			else
				ns_i2c_auto_init <= AUTO_STATE_2_TRANSFER_BYTE_1;
			end if;
		elsif (s_i2c_auto_init = AUTO_STATE_3_TRANSFER_BYTE_2) then
			if ((change_state = '1') and (rom_data(24) = '1')) then
				ns_i2c_auto_init <= AUTO_STATE_4_WAIT;
			elsif (change_state = '1') then
				ns_i2c_auto_init <= AUTO_STATE_6_INCREASE_COUNTER;
			else
				ns_i2c_auto_init <= AUTO_STATE_3_TRANSFER_BYTE_2;
			end if;
		elsif (s_i2c_auto_init = AUTO_STATE_4_WAIT) then
			if (transfer_complete = '0') then
				ns_i2c_auto_init <= AUTO_STATE_5_SEND_STOP_BIT;
			else
				ns_i2c_auto_init <= AUTO_STATE_4_WAIT;
			end if;
		elsif (s_i2c_auto_init = AUTO_STATE_5_SEND_STOP_BIT) then
			if (transfer_complete = '1') then
				ns_i2c_auto_init <= AUTO_STATE_6_INCREASE_COUNTER;
			else
				ns_i2c_auto_init <= AUTO_STATE_5_SEND_STOP_BIT;
			end if;
		elsif (s_i2c_auto_init = AUTO_STATE_6_INCREASE_COUNTER) then
			ns_i2c_auto_init <= AUTO_STATE_0_CHECK_STATUS;
		elsif (s_i2c_auto_init = AUTO_STATE_7_DONE) then
			ns_i2c_auto_init <= AUTO_STATE_7_DONE;
		else
			ns_i2c_auto_init <= AUTO_STATE_0_CHECK_STATUS;
		end if;
	end process;

	process (clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				data_out <= "00000000";
			elsif (s_i2c_auto_init = AUTO_STATE_1_SEND_START_BIT) then
				data_out <= rom_data(23 downto 16);
			elsif (s_i2c_auto_init = AUTO_STATE_0_CHECK_STATUS) then
				data_out <= rom_data(15 downto 8);
			elsif (s_i2c_auto_init = AUTO_STATE_2_TRANSFER_BYTE_1) then
				data_out <= rom_data(15 downto 8);
			elsif (s_i2c_auto_init = AUTO_STATE_3_TRANSFER_BYTE_2) then
				data_out <= rom_data( 7 downto 0);
			end if;
		end if;
	end process;

	process (clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				transfer_data <= '0';
			elsif (transfer_complete = '1') then
				transfer_data <= '0';
			elsif (s_i2c_auto_init = AUTO_STATE_1_SEND_START_BIT) then
				transfer_data <= '1';
			elsif (s_i2c_auto_init = AUTO_STATE_2_TRANSFER_BYTE_1) then
				transfer_data <= '1';
			elsif (s_i2c_auto_init = AUTO_STATE_3_TRANSFER_BYTE_2) then
				transfer_data <= '1';
			end if;
		end if;
	end process;

	process (clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				send_start_bit <= '0';
			elsif (transfer_complete = '1') then
				send_start_bit <= '0';
			elsif (s_i2c_auto_init = AUTO_STATE_1_SEND_START_BIT) then
				send_start_bit <= '1';
			end if;
		end if;
	end process;

	process (clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				send_stop_bit <= '0';
			elsif (transfer_complete = '1') then
				send_stop_bit <= '0';
			elsif (s_i2c_auto_init = AUTO_STATE_5_SEND_STOP_BIT) then
				send_stop_bit <= '1';
			end if;
		end if;
	end process;

	process (clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				auto_init_error <= '0';
			elsif (clear_error = '1') then
				auto_init_error <= '0';
			elsif ((s_i2c_auto_init = AUTO_STATE_6_INCREASE_COUNTER) and ack='1') then
				auto_init_error <= '1';
			end if;
		end if;
	end process;

	process (clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				rom_address_counter <= MIN_ROM_ADDRESS;
			elsif (s_i2c_auto_init = AUTO_STATE_6_INCREASE_COUNTER) then
				rom_address_counter <= rom_address_counter + "000001";
			end if;
		end if;
	end process;

	process (clk, reset, clear_error, ack, transfer_complete)				
	begin
		case (rom_address_counter) is
			
			-- Scrittura configurazione Audio: 7 bit di indirizzo + 9 bit di dati
			-- Nota: i primi 2 bit sono usati per comodita' per portare a 28 i bit e usare valori esadecimali!
			when "000000" 	=>	rom_data_buff	<=	"00" & "1100110100" & "0000000" & AUD_LINE_IN_LC;
			when "000001" 	=>	rom_data_buff	<=	"00" & "1100110100" & "0000001" & AUD_LINE_IN_RC;
			when "000010" 	=>	rom_data_buff	<=	"00" & "1100110100" & "0000010" & AUD_LINE_OUT_LC;
			when "000011" 	=>	rom_data_buff	<=	"00" & "1100110100" & "0000011" & AUD_LINE_OUT_RC;
			when "000100" 	=>	rom_data_buff	<= ("00" & "1100110100" & "0000100" & AUD_ADC_PATH)
												+ ("00" & "00000000000000000000000" & useMicInput & "00"); -- Microfono o Linein
			when "000101" 	=>	rom_data_buff	<=	"00" & "1100110100" & "0000101" & AUD_DAC_PATH;
			when "000110" 	=>	rom_data_buff	<=	"00" & "1100110100" & "0000110" & AUD_POWER;
			when "000111" 	=>	rom_data_buff	<=	"00" & "1100110100" & "0000111" & AUD_DATA_FORMAT;
			when "001000" 	=>	rom_data_buff	<=	"00" & "1100110100" & "0001000" & AUD_SAMPLE_CTRL;
			when "001001" 	=>	rom_data_buff	<=	"00" & "1100110100" & "0001001" & AUD_SET_ACTIVE;
			
			-- Scrittura configurazione Video
			when "001010" 	=>	rom_data_buff	<=	X"3401500";
			when "001011" 	=>	rom_data_buff	<=	X"3401741";
			when "001100" 	=>	rom_data_buff	<=	X"3403a16";
			when "001101" 	=>	rom_data_buff	<=	X"3405004";
			when "001110" 	=>	rom_data_buff	<=	X"340c305";
			when "001111" 	=>	rom_data_buff	<=	X"340c480";
			when "010000" 	=>	rom_data_buff	<=	X"3400e80";
			when "010001" 	=>	rom_data_buff	<=	X"3405020";
			when "010010" 	=>	rom_data_buff	<=	X"3405218";
			when "010011" 	=>	rom_data_buff	<=	X"34058ed";
			when "010100" 	=>	rom_data_buff	<=	X"34077c5";
			when "010101" 	=>	rom_data_buff	<=	X"3407c93";
			when "010110" 	=>	rom_data_buff	<=	X"3407d00";
			when "010111" 	=>	rom_data_buff	<=	X"340d048";
			when "011000" 	=>	rom_data_buff	<=	X"340d5a0";
			when "011001" 	=>	rom_data_buff	<=	X"340d7ea";
			when "011010" 	=>	rom_data_buff	<=	X"340e43e";
			when "011011" 	=>	rom_data_buff	<=	X"340ea0f";
			when "011100" 	=>	rom_data_buff	<=	X"3403112";
			when "011101" 	=>	rom_data_buff	<=	X"3403281";
			when "011110" 	=>	rom_data_buff	<=	X"3403384";
			when "011111" 	=>	rom_data_buff	<=	X"34037A0";
			when "100000" 	=>	rom_data_buff	<=	X"340e580";
			when "100001" 	=>	rom_data_buff	<=	X"340e603";
			when "100010"	=>	rom_data_buff	<=	X"340e785";
			when "100011" 	=>	rom_data_buff	<=	X"3405000";
			when "100100" 	=>	rom_data_buff	<=	X"3405100";
			when "100101" 	=>	rom_data_buff	<=	X"3400070";
			when "100110" 	=>	rom_data_buff	<=	X"3401010";
			when "100111" 	=>	rom_data_buff	<=	X"3400482";
			when "101000" 	=>	rom_data_buff	<=	X"3400860";
			when "101001" 	=>	rom_data_buff	<=	X"3400a18";
			when "101010" 	=>	rom_data_buff	<=	X"3401100";
			when "101011" 	=>	rom_data_buff	<=	X"3402b00";
			when "101100" 	=>	rom_data_buff	<=	X"3402c8c";
			when "101101" 	=>	rom_data_buff	<=	X"3402df2";
			when "101110" 	=>	rom_data_buff	<=	X"3402eee";
			when "101111" 	=>	rom_data_buff	<=	X"3402ff4";
			when "110000" 	=>	rom_data_buff	<=	X"34030d2";
			when "110001" 	=>	rom_data_buff	<=	X"3400e05";
			when others		=>	rom_data_buff	<=	X"1000000";
		end case;
	end process;

end behaviour;