-- **********************************************************
--   Corso di Reti Logiche - Progetto Registratore Portatile
--   Andrea Carrer - 729101
--   Modulo SYNC_FIFO.vhd
--   Versione 1.01 - 14.03.2013
-- **********************************************************

-- **********************************************************
-- Gestione FIFO con uguale clock per lettura e scrittura.
-- **********************************************************

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;

library Altera_mf;
	use altera_mf.altera_mf_components.all;

entity SYNC_FIFO is

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

end SYNC_FIFO;

architecture behaviour of SYNC_FIFO is

begin

	Sync_FIFO_Entity : scfifo generic map (
		add_ram_output_register	=> "OFF",
		intended_device_family	=> "Cyclone II",
		lpm_numwords			=> DATA_DEPTH,
		lpm_showahead			=> "ON",
		lpm_type				=> "scfifo",
		lpm_width				=> DATA_WIDTH,
		lpm_widthu				=> ADDR_WIDTH,
		overflow_checking		=> "OFF",
		underflow_checking		=> "OFF",
		use_eab					=> "ON"
		)
	port map (
		clock			=> clk,
		sclr			=> reset,
		data			=> write_data,
		wrreq			=> write_en,
		rdreq			=> read_en,
		empty			=> fifo_is_empty,
		full			=> fifo_is_full,
		usedw			=> words_used,
		q				=> read_data,

		-- Unused
		aclr			=> OPEN,
		almost_empty	=> OPEN,
		almost_full		=> OPEN
	);

end behaviour;