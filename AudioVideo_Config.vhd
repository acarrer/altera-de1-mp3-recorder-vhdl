-- **********************************************************
--   Corso di Reti Logiche - Progetto Registratore Portatile
--   Andrea Carrer - 729101
--   Modulo AudioVideo_Config.vhd
--   Versione 1.01 - 14.03.2013
-- **********************************************************

-- **********************************************************
-- Questo modulo setta i registri di controllo Audio/Video.
-- **********************************************************

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;
	use IEEE.std_logic_misc.all;

entity AudioVideo_Config is port(
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

end AudioVideo_Config;

architecture behaviour of AudioVideo_Config is

	-- Parametri
	constant I2C_BUS_MODE:				std_logic_vector(0 downto 0)	:= "0";
	constant MIN_ROM_ADDRESS:			std_logic_vector(5 downto 0) 	:= "000000"; 	--6'h00;
	constant MAX_ROM_ADDRESS:			std_logic_vector(5 downto 0) 	:= "001010"; 	--6'h0A;
	
	--N		Nome							Valore		Significati principali
	--0		Left Line In					000011000	[4:0] = Volume canale input sinistro
	--1		Right Line In					000011000	[4:0] = Volume canale input destro
	--2		Left Headphone Out				001110111	[6:0] = Volume canale output sinistro
	--3		Right Headphone Out				001110111	[6:0] = Volume canale output destro
	--4		Analogue Audio Path Control		000010000	[2] = Mic/Linein, Altri: mute, boost, effetti (tutto a zero)
	--5		Digital Audio Path Control		000000110	[0] = filtro passa alto, [2:1] = frequenza (11=48 KHz)
	--6		Power Down Control				000000000	Per disabilitare vari componenti
	--7		Digital Audio Interface Format	001001101	[1:0] = formato audio, [3:2] = lunghezza input dati (11=32 bit)
	--8		Sampling Control				000000000	[0] = Modo (normale)
	--9		Active Control					000000001	[0] = Interfaccia attiva/non attiva

	constant AUD_LINE_IN_LC:			std_logic_vector(8 downto 0) 	:= "000011000"; --9'd24;
	constant AUD_LINE_IN_RC:			std_logic_vector(8 downto 0) 	:= "000011000"; --9'd24;
	constant AUD_LINE_OUT_LC:			std_logic_vector(8 downto 0) 	:= "001110111";	--9'd119;
	constant AUD_LINE_OUT_RC:			std_logic_vector(8 downto 0) 	:= "001110111";	--9'd119;
	constant AUD_ADC_PATH:				std_logic_vector(8 downto 0) 	:= "000010001"; --9'd17;
	constant AUD_DAC_PATH:				std_logic_vector(8 downto 0) 	:= "000000110"; --9'd6;
	constant AUD_POWER:					std_logic_vector(8 downto 0) 	:= "000000000"; --9'h000;
	constant AUD_DATA_FORMAT:			std_logic_vector(8 downto 0) 	:= "001001101"; --9'd77;
	constant AUD_SAMPLE_CTRL:			std_logic_vector(8 downto 0) 	:= "000000000"; --9'd0;
	constant AUD_SET_ACTIVE:			std_logic_vector(8 downto 0) 	:= "000000001"; --9'h001;

	-- Costanti
	constant I2C_STATE_0_IDLE:			std_logic_vector(1 downto 0) 	:= "00"; 	-- 2'h0;
	constant I2C_STATE_1_START:			std_logic_vector(1 downto 0) 	:= "01"; 	-- 2'h1;
	constant I2C_STATE_2_TRANSFERING:	std_logic_vector(1 downto 0) 	:= "10"; 	-- 2'h2;
	constant I2C_STATE_3_COMPLETE:		std_logic_vector(1 downto 0) 	:= "11"; 	-- 2'h3;

	-- Segnali
	signal internal_reset:			std_logic;

	signal valid_operation:			std_logic;

	signal clk_400KHz:				std_logic;
	signal start_and_stop_en:		std_logic;
	signal change_output_bit_en:	std_logic;

	signal enable_clk_s:			std_logic;

	signal address:					std_logic_vector(1 downto 0);
	signal byteenable:				std_logic_vector(3 downto 0);
	signal chipselect:				std_logic;
	signal read_s:					std_logic;
	signal write_s:					std_logic;
	signal writedata:				std_logic_vector(31 downto 0);

	signal readdata:				std_logic_vector(31 downto 0);
	signal waitrequest:				std_logic;

	signal clear_status_bits:		std_logic;

	signal send_start_bit:			std_logic;
	signal send_stop_bit:			std_logic;

	signal auto_init_data:			std_logic_vector(7 downto 0);
	signal auto_init_transfer_data:	std_logic;
	signal auto_init_start_bit:		std_logic;
	signal auto_init_stop_bit:		std_logic;
	signal auto_init_complete:		std_logic;
	signal auto_init_error:			std_logic;

	signal transfer_data:			std_logic;
	signal transfer_complete:		std_logic;

	signal i2c_ack:					std_logic;
	signal i2c_received_data:		std_logic_vector(7 downto 0);

	-- Internal Registers
	signal data_to_transfer:		std_logic_vector(7 downto 0);
	signal num_bits_to_transfer:	integer; --std_logic_vector(2 downto 0);

	signal read_byte:				std_logic;
	signal transfer_is_read:		std_logic;

	-- State Machine Registers
	signal ns_alavon_slave:			std_logic_vector(1 downto 0);
	signal s_alavon_slave:			std_logic_vector(1 downto 0);
	
	-- Segnali di buffer
	signal buff1_sig:				std_logic;
	signal buff2_sig:				std_logic;
	signal buff3_sig:				std_logic;
	
	signal addrIs00:				std_logic;
	signal addrIs01:				std_logic;
	signal addrIs10:				std_logic;
	signal addrIs11:				std_logic;
	
	component Slow_Clock_Generator is	
		generic (
			COUNTER_BITS:			integer := 10;
			COUNTER_INC:			std_logic_vector(9 downto 0) := "0000000001"
		);	
		port (
			clk:					in std_logic;
			reset:					in std_logic;
			enable_clk:				in std_logic;
			new_clk:				out std_logic;
			ris_edge:				out std_logic;
			fal_edge:				out std_logic;
			middle_of_high_level:	out std_logic;
			middle_of_low_level:	out std_logic
		);
	end component;
	
	component AudioVideo_Init is
		generic (
			MIN_ROM_ADDRESS:	std_logic_vector(5 downto 0);
			MAX_ROM_ADDRESS:	std_logic_vector(5 downto 0);
			AUD_LINE_IN_LC:		std_logic_vector(8 downto 0);
			AUD_LINE_IN_RC:		std_logic_vector(8 downto 0);
			AUD_LINE_OUT_LC:	std_logic_vector(8 downto 0);
			AUD_LINE_OUT_RC:	std_logic_vector(8 downto 0);
			AUD_ADC_PATH:		std_logic_vector(8 downto 0);
			AUD_DAC_PATH:		std_logic_vector(8 downto 0);
			AUD_POWER:			std_logic_vector(8 downto 0);
			AUD_DATA_FORMAT:	std_logic_vector(8 downto 0);
			AUD_SAMPLE_CTRL:	std_logic_vector(8 downto 0);
			AUD_SET_ACTIVE:		std_logic_vector(8 downto 0)
		);
		port (
			clk:					in std_logic;
			reset:					in std_logic;
			clear_error:			in std_logic;
			ack:					in std_logic;
			transfer_complete:		in std_logic;
			data_out:				out std_logic_vector(7 downto 0);
			transfer_data:			out std_logic;
			send_start_bit:			out std_logic;
			send_stop_bit:			out std_logic;
			auto_init_complete:		out std_logic;
			auto_init_error:		out std_logic;
			useMicInput:			in std_logic
		);
	end component;
	
	component I2C_Controller is
		generic (
			I2C_BUS_MODE:			std_logic_vector(0 downto 0)
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
			num_bits_to_transfer:	integer; --in std_logic_vector(2 downto 0);
			i2c_sdata:				inout std_logic;
			i2c_sclk:				out std_logic;
			i2c_scen:				out std_logic;
			enable_clk:				out std_logic;
			ack:					out std_logic;
			data_from_i2c:			buffer std_logic_vector(7 downto 0);
			transfer_complete:		out std_logic
		);	
	end component;

begin

	-- Segnali buffer
	buff1_sig <= '1' when (s_alavon_slave /= I2C_STATE_0_IDLE) else '0';
	buff2_sig <= '1' when (s_alavon_slave /= I2C_STATE_1_START) else '0';
	buff3_sig <= '1' when (s_alavon_slave /= I2C_STATE_2_TRANSFERING) else '0';

	addrIs00 <= '1' when address = "00" else '0';
	addrIs01 <= '1' when address = "01" else '0';
	addrIs10 <= '1' when address = "10" else '0';
	addrIs11 <= '1' when address = "11" else '0';
	
	ob_readdata		<= readdata;
	ob_waitrequest	<= waitrequest;

	readdata(31 downto 8)	<= "000000000000000000000000";
	readdata( 7 downto 4)	<= i2c_received_data(7 downto 4) when addrIs11='1' else "0000";
	readdata(3)				<= auto_init_error when addrIs01='1' else
							   i2c_received_data(3) when addrIs11='1' else '0';
	readdata(2)				<= not auto_init_complete when addrIs01='1' else 
							   i2c_received_data(2) when addrIs11='1' else '0';
	readdata(1)				<= (buff1_sig) when addrIs01='1' else 
							   i2c_received_data(1) when addrIs11='1' else '0';
	readdata(0)				<= i2c_ack when addrIs01='1' else
							   i2c_received_data(0) when addrIs11='1' else '0';

	waitrequest 	<= valid_operation and ((write_s and buff2_sig) or (read_s and not(transfer_complete)));

	address				<= ob_address(1 downto 0);
	byteenable			<= ob_byteenable;
	chipselect			<= ob_chipselect;
	read_s				<= ob_read;
	write_s				<= ob_write;
	writedata			<= ob_writedata;
	internal_reset		<= reset or	(
							chipselect 
							and byteenable(0)
							and addrIs00
							and write_s
							and writedata(0)
							);
	valid_operation		<= chipselect and byteenable(0) 
							and (
								(addrIs00 and write_s and (not writedata(0)))
								or (addrIs10 and write_s)
								or addrIs11)
								;
	clear_status_bits	<= chipselect and addrIs01 and write_s;
	transfer_data		<= auto_init_transfer_data or (not buff3_sig);
	send_start_bit		<= auto_init_start_bit 
							or (chipselect 
							and byteenable(0)
							and addrIs00
							and write_s and writedata(2)
							);
	send_stop_bit 		<= auto_init_stop_bit or 
							(chipselect 
							and byteenable(0)
							and addrIs00
							and write_s
							and writedata(1)
							);

	process (clk)
	begin
		if (rising_edge(clk)) then
			if (internal_reset = '1') then
				s_alavon_slave <= I2C_STATE_0_IDLE;
			else
				s_alavon_slave <= ns_alavon_slave;
			end if;
		end if;
	end process;

	process (clk,			
	         reset,		
	         ob_address,		
	         ob_byteenable,
	         ob_chipselect,	
	         ob_read,		
	         ob_write,		
	         ob_writedata)	
	        
	begin
		ns_alavon_slave <= I2C_STATE_0_IDLE;

		if (s_alavon_slave = I2C_STATE_0_IDLE) then
			if ((valid_operation = '1') and (auto_init_complete = '1')) then
				ns_alavon_slave <= I2C_STATE_1_START;
			else
				ns_alavon_slave <= I2C_STATE_0_IDLE;
			end if;
		elsif (s_alavon_slave = I2C_STATE_1_START) then
			ns_alavon_slave <= I2C_STATE_2_TRANSFERING;
		elsif (s_alavon_slave = I2C_STATE_2_TRANSFERING) then
			if (transfer_complete = '1') then
				ns_alavon_slave <= I2C_STATE_3_COMPLETE;
			else
				ns_alavon_slave <= I2C_STATE_2_TRANSFERING;
			end if;
		elsif (s_alavon_slave = I2C_STATE_3_COMPLETE) then
			ns_alavon_slave <= I2C_STATE_0_IDLE;
		else
			ns_alavon_slave <= I2C_STATE_0_IDLE;
		end if;
	end process;

	process (clk)
	begin
		if (rising_edge(clk)) then
			if (internal_reset = '1') then
				data_to_transfer		<= "00000000"; --8'h00;
				num_bits_to_transfer	<= 3;
			elsif (auto_init_complete = '0') then
				data_to_transfer		<= auto_init_data;
				num_bits_to_transfer	<= 7;
			elsif (s_alavon_slave = I2C_STATE_1_START) then
				num_bits_to_transfer 	<= 7;
				if ((ob_address = "000") and writedata(2) = '1') then
					data_to_transfer 	<= "00110100"; --8'h34;
				elsif ((ob_address = "100") and writedata(2) = '1') then
					data_to_transfer 	<= "10000000";-- or writedata(3);
				else
					data_to_transfer 	<= writedata(7 downto 0);
				end if;
			end if;
		end if;
	end process;

	process (clk)
	begin
		if (rising_edge(clk)) then
			if (reset = '1') then
				read_byte <= '0';
			elsif (s_alavon_slave = I2C_STATE_1_START) then
				read_byte <= read_s;
			end if;
		end if;
	end process;

	process (clk)
	begin
		if (rising_edge(clk)) then
			if (reset = '1') then
				transfer_is_read <= '0';
			elsif ((s_alavon_slave = I2C_STATE_1_START) and (address = "00")) then
				transfer_is_read <= writedata(3);
			end if;
		end if;
	end process;

	Clock_Generator_400KHz: Slow_Clock_Generator
		generic map (
			COUNTER_BITS	=> 10,
			COUNTER_INC		=> "0000000001"
		)
		port map (
			clk						=> clk,
			reset					=> internal_reset,
			enable_clk				=> enable_clk_s,
			new_clk					=> clk_400KHz,
			ris_edge				=> OPEN,
			fal_edge				=> OPEN,
			middle_of_high_level	=> start_and_stop_en,
			middle_of_low_level		=> change_output_bit_en
		);
		 
	Auto_Initialize: AudioVideo_Init
		generic map (
			MIN_ROM_ADDRESS	=> MIN_ROM_ADDRESS,
			MAX_ROM_ADDRESS	=> MAX_ROM_ADDRESS,
			AUD_LINE_IN_LC	=> AUD_LINE_IN_LC,
			AUD_LINE_IN_RC	=> AUD_LINE_IN_RC,
			AUD_LINE_OUT_LC	=> AUD_LINE_OUT_LC,
			AUD_LINE_OUT_RC	=> AUD_LINE_OUT_RC,
			AUD_ADC_PATH	=> AUD_ADC_PATH,
			AUD_DAC_PATH	=> AUD_DAC_PATH,
			AUD_POWER		=> AUD_POWER,
			AUD_DATA_FORMAT	=> AUD_DATA_FORMAT,
			AUD_SAMPLE_CTRL	=> AUD_SAMPLE_CTRL,
			AUD_SET_ACTIVE	=> AUD_SET_ACTIVE
		)
		port map (
			clk					=> clk,
			reset				=> internal_reset,
			clear_error			=> clear_status_bits,
			ack					=> i2c_ack,
			transfer_complete	=> transfer_complete,
			data_out			=> auto_init_data,
			transfer_data		=> auto_init_transfer_data,
			send_start_bit		=> auto_init_start_bit,
			send_stop_bit		=> auto_init_stop_bit,
			auto_init_complete	=> auto_init_complete,
			auto_init_error		=> auto_init_error,
			useMicInput			=> useMicInput
		);

	I2C_Controller_Entity: I2C_Controller 
		generic map(
			I2C_BUS_MODE			=> I2C_BUS_MODE
		)
		port map(
			clk						=> clk,
			reset					=> internal_reset,
			clear_ack				=> clear_status_bits,
			clk_400KHz				=> clk_400KHz,
			start_and_stop_en		=> start_and_stop_en,
			change_output_bit_en	=> change_output_bit_en,
			send_start_bit			=> send_start_bit,
			send_stop_bit			=> send_stop_bit,
			data_in					=> data_to_transfer,
			transfer_data			=> transfer_data,
			read_byte				=> read_byte,
			num_bits_to_transfer	=> num_bits_to_transfer,
			i2c_sdata				=> I2C_SDAT,
			i2c_sclk				=> I2C_SCLK,
			i2c_scen				=> OPEN,
			enable_clk				=> enable_clk_s,
			ack						=> i2c_ack,
			data_from_i2c			=> i2c_received_data,
			transfer_complete		=> transfer_complete
		);

end behaviour;