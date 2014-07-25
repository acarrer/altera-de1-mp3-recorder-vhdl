-- **********************************************************
--   Corso di Reti Logiche - Progetto Registratore Portatile
--   Andrea Carrer - 729101
--   Modulo I2C_Controller.vhd
--   Versione 1.01 - 14.03.2013
-- **********************************************************

-- **********************************************************
-- Modulo che si occupa della comunicazione con il chip audio
-- e i registri di controllo utilizzando il protocollo I2C.
-- **********************************************************

library ieee;
   use ieee.std_logic_1164.all;
   use ieee.std_logic_unsigned.all;

entity I2C_Controller is generic (
		I2C_BUS_MODE: std_logic := '0'
	);
	port (
		clk:					in std_logic;
		reset:					in std_logic;
		clear_ack:				in std_logic;
		clk_400KHz:				in std_logic;
		start_and_stop_en:		in std_logic;
		change_output_bit_en:	in std_logic;
		send_start_bit:			in std_logic;
		send_stop_bit:			in std_logic;
		data_in:				in std_logic_vector(7 downto 0);
		transfer_data:			in std_logic;
		read_byte:				in std_logic;
		num_bits_to_transfer:	in integer; 		-- std_logic_vector(2 downto 0);
		i2c_sdata:				inout std_logic;	--	I2C Data
		i2c_sclk:				out std_logic;		--	I2C Clock
		i2c_scen:				out std_logic;
		enable_clk:				out std_logic;
		ack:					out std_logic;
		data_from_i2c:			buffer std_logic_vector(7 downto 0);
		transfer_complete:		out std_logic
	);

end I2C_Controller;

architecture behaviour of I2C_Controller is

	-- Stati della FSM
	constant I2C_STATE_0_IDLE:			std_logic_vector (2 downto 0) := "000";
	constant I2C_STATE_1_PRE_START:		std_logic_vector (2 downto 0) := "001";
	constant I2C_STATE_2_START_BIT:		std_logic_vector (2 downto 0) := "010";
	constant I2C_STATE_3_TRANSFER_BYTE:	std_logic_vector (2 downto 0) := "011";
	constant I2C_STATE_4_TRANSFER_ACK:	std_logic_vector (2 downto 0) := "100";
	constant I2C_STATE_5_STOP_BIT:		std_logic_vector (2 downto 0) := "101";
	constant I2C_STATE_6_COMPLETE:		std_logic_vector (2 downto 0) := "110";

	signal current_bit:					integer; 	--std_logic_vector (2 downto 0);
	signal current_byte:				std_logic_vector (7 downto 0);
	signal ns_i2c_transceiver:			std_logic_vector (2 downto 0);
	signal s_i2c_transceiver:			std_logic_vector (2 downto 0);
	
	-- Segnali buffer
	signal buff1:						std_logic;
	signal buff2:						std_logic;

begin
	
	buff1				<= '0' when s_i2c_transceiver = I2C_STATE_0_IDLE else '1';
	buff2				<= '0' when s_i2c_transceiver = I2C_STATE_6_COMPLETE else '1';
			
			
	i2c_sclk			<= clk_400KHz when I2C_BUS_MODE = '0' else 
						   clk_400KHz when ((s_i2c_transceiver = I2C_STATE_3_TRANSFER_BYTE)
										   or (s_i2c_transceiver = I2C_STATE_4_TRANSFER_ACK))
									  else '0';

	i2c_sdata			<= 
							'0' when (s_i2c_transceiver = I2C_STATE_2_START_BIT) else
							'0' when (s_i2c_transceiver = I2C_STATE_5_STOP_BIT) else
							'0' when ((s_i2c_transceiver = I2C_STATE_4_TRANSFER_ACK) and read_byte='1') else
	  current_byte(current_bit) when ((s_i2c_transceiver = I2C_STATE_3_TRANSFER_BYTE) and read_byte='0') else 
							'Z';

	enable_clk			<=  buff1 and buff2;

	transfer_complete 	<= '1' when (s_i2c_transceiver = I2C_STATE_6_COMPLETE) else '0';

	process (clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				s_i2c_transceiver <= I2C_STATE_0_IDLE;
			else
				s_i2c_transceiver <= ns_i2c_transceiver;
			end if;
		end if;
	end process;

	process(all)
	begin
		ns_i2c_transceiver <= I2C_STATE_0_IDLE;

		if s_i2c_transceiver = I2C_STATE_0_IDLE then
			if ((send_start_bit = '1') and (clk_400KHz = '0')) then
				ns_i2c_transceiver <= I2C_STATE_1_PRE_START;
			elsif (send_start_bit = '1') then
				ns_i2c_transceiver <= I2C_STATE_2_START_BIT;
			elsif (send_stop_bit = '1') then
				ns_i2c_transceiver <= I2C_STATE_5_STOP_BIT;
			elsif (transfer_data = '1') then
				ns_i2c_transceiver <= I2C_STATE_3_TRANSFER_BYTE;
			else
				ns_i2c_transceiver <= I2C_STATE_0_IDLE;
			end if;
		elsif s_i2c_transceiver = I2C_STATE_1_PRE_START then
			if (start_and_stop_en = '1') then
				ns_i2c_transceiver <= I2C_STATE_2_START_BIT;
			else
				ns_i2c_transceiver <= I2C_STATE_1_PRE_START;
			end if;
		elsif s_i2c_transceiver = I2C_STATE_2_START_BIT then
			if (change_output_bit_en = '1') then
				if ((transfer_data = '1') and (I2C_BUS_MODE = '0')) then
					ns_i2c_transceiver <= I2C_STATE_3_TRANSFER_BYTE;
				else
					ns_i2c_transceiver <= I2C_STATE_6_COMPLETE;
				end if;
			else
				ns_i2c_transceiver <= I2C_STATE_2_START_BIT;
			end if;
		elsif s_i2c_transceiver = I2C_STATE_3_TRANSFER_BYTE then
			if ((current_bit = 0) and (change_output_bit_en = '1')) then
				if ((I2C_BUS_MODE = '0') or (num_bits_to_transfer = 6)) then
					ns_i2c_transceiver <= I2C_STATE_4_TRANSFER_ACK;
				else
					ns_i2c_transceiver <= I2C_STATE_6_COMPLETE;
				end if;
			else
				ns_i2c_transceiver <= I2C_STATE_3_TRANSFER_BYTE;
			end if;
		elsif s_i2c_transceiver = I2C_STATE_4_TRANSFER_ACK then
			if (change_output_bit_en = '1') then
				ns_i2c_transceiver <= I2C_STATE_6_COMPLETE;
			else
				ns_i2c_transceiver <= I2C_STATE_4_TRANSFER_ACK;
			end if;
		elsif s_i2c_transceiver = I2C_STATE_5_STOP_BIT then
			if (start_and_stop_en = '1') then
				ns_i2c_transceiver <= I2C_STATE_6_COMPLETE;
			else
				ns_i2c_transceiver <= I2C_STATE_5_STOP_BIT;
			end if;
		elsif s_i2c_transceiver = I2C_STATE_6_COMPLETE then
			if (transfer_data = '0') then
				ns_i2c_transceiver <= I2C_STATE_0_IDLE;
			else
				ns_i2c_transceiver <= I2C_STATE_6_COMPLETE;
			end if;
		else
			ns_i2c_transceiver <= I2C_STATE_0_IDLE;
		end if;
	end process;

	process (clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				i2c_scen <= '1';
			elsif (change_output_bit_en='1' and (s_i2c_transceiver = I2C_STATE_2_START_BIT)) then
				i2c_scen <= '0';
			elsif (s_i2c_transceiver = I2C_STATE_5_STOP_BIT) then
				i2c_scen <= '1';
			end if;
		end if;
	end process;

	process (clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				ack <= '0';
			elsif (clear_ack = '1') then
				ack <= '0';
			elsif (start_and_stop_en='1' and (s_i2c_transceiver = I2C_STATE_4_TRANSFER_ACK)) then
				ack <= i2c_sdata xor I2C_BUS_MODE;
			end if;
		end if;
	end process;

	process (clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				data_from_i2c <= "00000000";
			elsif (start_and_stop_en='1' and (s_i2c_transceiver = I2C_STATE_3_TRANSFER_BYTE)) then
				data_from_i2c <= data_from_i2c(6 downto 0) & i2c_sdata;
			end if;
		end if;
	end process;

	process (clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
			current_bit	<= 0;
			elsif ((s_i2c_transceiver = I2C_STATE_3_TRANSFER_BYTE) and 
					(change_output_bit_en = '1')) then
				current_bit <= current_bit - 1;
			elsif not(s_i2c_transceiver = I2C_STATE_3_TRANSFER_BYTE) then
				current_bit <= num_bits_to_transfer;
			end if;
		end if;
	end process;
	
	process (clk)
	begin
		if rising_edge(clk) then
			if (reset = '1') then
				current_byte <= "00000000";
			elsif ((s_i2c_transceiver = I2C_STATE_0_IDLE) or 
					 (s_i2c_transceiver = I2C_STATE_2_START_BIT)) then
				current_byte <= data_in;
			end if;
		end if;
	end process;
	
end behaviour;