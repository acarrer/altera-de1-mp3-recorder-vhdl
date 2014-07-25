// **********************************************************
//   Corso di Reti Logiche - Progetto Registratore Portatile
//   Andrea Carrer - 729101
//   Modulo RegistratorePortatile.v
//   Versione 1.02 - 18.03.2013
// **********************************************************

// **********************************************************
// Modulo principale scritto in Verilog.
// Definisce la logica e le connessioni tra i diversi moduli:
// - PlayRecord: 		gestione comandi registratore
// - Display:			gestione segnali grafica
// - Audio_Controller:	interfaccia con il chip WM8731
// - VGA_Adapter:		interfaccia con l'uscita VGA
// - SDRAM:				interfaccia con la SDRAM
// E gestisce i componenti I/O della scheda Altera DE1
// **********************************************************

// --------------------------------------------------------------------------------------------
// -------------------------------------------------------------- Definizione modulo principale
// --------------------------------------------------------------------------------------------

module RegistratorePortatile(
	inout	[15:0]	DRAM_DQ,			//	SDRAM Data bus 16 Bits
	output	[11:0]	DRAM_ADDR,			//	SDRAM Address bus 12 Bits
	output			DRAM_LDQM,			//	SDRAM Low-byte Data Mask 
	output			DRAM_UDQM,			//	SDRAM High-byte Data Mask
	output			DRAM_WE_N,			//	SDRAM Write Enable
	output			DRAM_CAS_N,			//	SDRAM Column Address Strobe
	output			DRAM_RAS_N,			//	SDRAM Row Address Strobe
	output			DRAM_CS_N,			//	SDRAM Chip Select
	output			DRAM_BA_0,			//	SDRAM Bank Address 0
	output			DRAM_BA_1,			//	SDRAM Bank Address 1
	output			DRAM_CLK,			//	SDRAM Clock
	output			DRAM_CKE,			//	SDRAM Clock Enable

	input			CLOCK_50,			//	On Board 50 MHz

	input	[3:0]	KEY,				//	Pushbutton[3:0]
	input	[9:0]	SW,					//	Toggle Switch[9:0]
	output	[6:0]	HEX0,				//	Seven Segment Digit 0
	output	[6:0]	HEX1,				//	Seven Segment Digit 1
	output	[6:0]	HEX2,				//	Seven Segment Digit 2
	output	[6:0]	HEX3,				//	Seven Segment Digit 3
	output	[7:0]	LEDG,				//	LED Green[7:0]
	output	[9:0]	LEDR,				//	LED Red[9:0]

	inout			AUD_ADCLRCK,		//	Audio CODEC ADC LR Clock
	input			AUD_ADCDAT,			//	Audio CODEC ADC Data
	inout			AUD_DACLRCK,		//	Audio CODEC DAC LR Clock
	output			AUD_DACDAT,			//	Audio CODEC DAC Data
	inout			AUD_BCLK,			//	Audio CODEC Bit-Stream Clock
	output			AUD_XCK,			//	Audio CODEC Chip Clock

	inout			I2C_SDAT,			//	I2C Data
	output			I2C_SCLK,			//	I2C Clock

	output			VGA_CLK,   			//	VGA Clock
	output			VGA_HS,				//	VGA H_SYNC
	output			VGA_VS,				//	VGA V_SYNC
	output			VGA_BLANK,			//	VGA BLANK
	output			VGA_SYNC,			//	VGA SYNC
	output	[9:0]	VGA_R,   			//	VGA Red[9:0]
	output	[9:0]	VGA_G,	 			//	VGA Green[9:0]
	output	[9:0]	VGA_B   			//	VGA Blue[9:0]
);

// --------------------------------------------------------------------------------------------
// ------------------------------------------------------------------------ Definizione segnali
// --------------------------------------------------------------------------------------------

// Segnali usati per leggere e scrivere dalla RAM
wire [21:0] ram_addr;								// Indirizzamento a 22 bit
wire [15:0] ram_data_in, ram_data_out;				// Bus dati a 16 bit I/O
wire ram_valid, ram_waitrq, ram_read, ram_write;	// Segnali di abilitazione per lettura/scrittura

wire [21:0] ram_addr_max;							// Memorizza l'ultimo banco di RAM memorizzato
wire playLimitReached;								// A 1 se durante il play si raggiunge la fine della registrazione

// Segnali per gestione lettura/scrittura audio
wire [15:0] audio_out, audio_in;					// Bus a 16 bit
wire audio_out_allowed, audio_in_available;			// Segnali di controllo abilitazione lettura/scrittura audio
wire write_audio_out, read_audio_in;

// Segnali per interfaccia con VGA
wire vga_color;										// Colore (monocromatico, pixel acceso/spento)
wire [8:0] vga_x;									// x massimo = 319 (9 bit)
wire [7:0] vga_y;									// y massimo = 239 (8 bit)
wire vga_plot;										// Abilitazione a scrittura pixel

// Visualizzo l'uscita se sono in Play, altrimenti visualizzo l'ingresso del microfono
wire [15:0] display_data = play_Cmd ? audio_out : audio_in;
reg [15:0] display_data_scaled;						// Dati in scala usati per VGA e led rossi (volume)

wire useMicInput;									// Quando e' a 1 usa il microfono, altrimenti il LineIn

reg [25:0] blink_cnt;								// Usato per blink pausa

// Contatore di secondi
wire [7:0] secondsCounter;										// Contatore di secondi durante Play & Rec
wire [3:0] secondsCounter0, secondsCounter1, secondsCounter2; 	// BCD
wire [7:0] seconds_max;											// Memorizza i secondi memorizzati con l'ultima registrazione
wire [3:0] seconds_max0, seconds_max1, seconds_max2; 			// BCD
integer 	cnt_clock;
wire 		CLOCK_1S;

// --------------------------------------------------------------------------------------------
// --------------------------------------------------------- Definizione input dalla Altera DE1
// --------------------------------------------------------------------------------------------

// Tasti e switch per comandi
wire reset = 			!KEY[0];					// Reset del sistema
wire AudioInChanged = 	!KEY[1];					// Gestione del soft reset del chip audio
wire DisplayRamAddr =	!KEY[2];					// Se premuto visualizza l'indirizzo RAM anziche' i secondi
wire play_Cmd = 		SW[0];						// Riproduce l'audio
wire pause_Cmd = 		SW[1];						// Mette in pausa
wire record_Cmd = 		SW[2];						// Registra
wire [1:0] speed = 		SW[4:3];					// Settaggi di velocita riproduzione
wire [1:0] scale = 		SW[6:5];					// Scala di visualizzazione dell'onda
wire showMaxAddr = 		SW[7];						// Visualizzazione del limite dell'ultima registrazione

// --------------------------------------------------------------------------------------------
// ------------------------------------------------ Definizione output diretti sulla Altera DE1
// --------------------------------------------------------------------------------------------

// Spie per livello audio (volume) sui led rossi
assign LEDR[0] = display_data_scaled[15] ? 1'b0 : display_data_scaled[0];
assign LEDR[1] = display_data_scaled[15] ? 1'b0 : display_data_scaled[2];
assign LEDR[2] = display_data_scaled[15] ? 1'b0 : display_data_scaled[4];
assign LEDR[3] = display_data_scaled[15] ? 1'b0 : display_data_scaled[6];
assign LEDR[4] = display_data_scaled[15] ? 1'b0 : display_data_scaled[8];
assign LEDR[5] = display_data_scaled[15] ? 1'b0 : display_data_scaled[10];
assign LEDR[6] = display_data_scaled[15] ? 1'b0 : display_data_scaled[12];
assign LEDR[7] = display_data_scaled[15] ? 1'b0 : display_data_scaled[14];

// Spia per la pausa
assign LEDG[7] = pause_Cmd & (play_Cmd | record_Cmd) ? blink_cnt[25] : 1'b0;
assign LEDG[6] = play_Cmd & playLimitReached;

// Spia per reset
assign LEDG[0] = reset;

// Spia per input audio
assign LEDG[1] = useMicInput;

// Clock 1S (debug)
assign LEDG[2] = CLOCK_1S & (play_Cmd | record_Cmd) & !pause_Cmd &!playLimitReached;

// Led non usati
assign LEDR[9:8] = 0;
assign LEDG[5:3] = 0;

// --------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------- Processi
// --------------------------------------------------------------------------------------------

// Intercetto il cambio di input per generare un "soft reset" del codec
// Visto che il settaggio della periferica deve essere fatto allo startup del CODEC

always @(posedge(AudioInChanged))
	useMicInput = !useMicInput;
		
// Calcolo dei dati in base alla scala scelta: piu' e' alto il valore di scala piu'
// Viene ridotta l'altezza della forma d'onda visualizzata
always @(*)
	case(scale)
		0: display_data_scaled = display_data;
		1: display_data_scaled = {{5{display_data[15]}}, display_data[14:4]};
		2: display_data_scaled = {{9{display_data[15]}}, display_data[14:8]};
		3: display_data_scaled = {{13{display_data[15]}}, display_data[14:12]};
	endcase

// Blinking della pausa
always @(posedge CLOCK_50) blink_cnt++;

// Memorizzazione dell'ultimo indirizzo registrato
always @(negedge record_Cmd)
begin
	ram_addr_max = ram_addr;
	seconds_max = secondsCounter;
end

// Generazione clock a 2 Hz per contare i secondi
always @(posedge CLOCK_50)
	begin
		if (cnt_clock == 25000000)
			begin
				CLOCK_1S <= !CLOCK_1S;
				cnt_clock <= 0;
			end
		else
			cnt_clock <= cnt_clock + 1;
	end

// --------------------------------------------------------------------------------------------
// ------------------------------------------------------------- Collegamenti ai moduli esterni
// --------------------------------------------------------------------------------------------

// Modulo PLL generato con la megafunction ALTPLL
SDRAM_PLL SDRAM_PLL_Entity(	
	.inclk0(CLOCK_50),
	.c0(DRAM_CLK), 
	.c1(VGA_CLK), 
	.c2(AUD_XCK)
	);

// Modulo generato dal SOPC builder
sdram SDRAM_Entity(
	.zs_addr(DRAM_ADDR), 
	.zs_ba({DRAM_BA_1,DRAM_BA_0}), 
	.zs_cas_n(DRAM_CAS_N), 
	.zs_cke(DRAM_CKE), 
	.zs_cs_n(DRAM_CS_N), 
	.zs_dq(DRAM_DQ),
	.zs_dqm({DRAM_UDQM,DRAM_LDQM}), 
	.zs_ras_n(DRAM_RAS_N), 
	.zs_we_n(DRAM_WE_N),
	.clk(CLOCK_50), 
	.az_addr(ram_addr), 
	.az_be_n(2'b00), 
	.az_cs(1), 
	.az_data(ram_data_in), 
	.az_rd_n(!ram_read), 
	.az_wr_n(!ram_write),
	.reset_n(!reset), 
	.za_data(ram_data_out), 
	.za_valid(ram_valid), 
	.za_waitrequest(ram_waitrq)
	);

// Lettura e scrittura sul chip audio
Audio_Controller Audio_Controller_Entity(
	.clk(CLOCK_50), 
	.reset(reset | AudioInChanged), 
	.clear_audio_in_memory(), 
	.read_audio_in(read_audio_in), 
	.clear_audio_out_memory(),
	.left_channel_audio_out({audio_out, 16'b0}), 
	.right_channel_audio_out({audio_out, 16'b0}), 
	.write_audio_out(write_audio_out),
	.AUD_ADCDAT(AUD_ADCDAT), 
	.AUD_BCLK(AUD_BCLK),
	.AUD_ADCLRCK(AUD_ADCLRCK),
	.AUD_DACLRCK(AUD_DACLRCK),
	.I2C_SDAT(I2C_SDAT),
	.audio_in_available(audio_in_available),
	.left_channel_audio_in({audio_in, 16'bx}),
	.right_channel_audio_in(),
	.audio_out_allowed(audio_out_allowed),
	.AUD_XCK(),
	.AUD_DACDAT(AUD_DACDAT),
	.I2C_SCLK(I2C_SCLK),
	.useMicInput(useMicInput)
	);

// Gestisce registrazione su RAM e riproduzione da RAM dell'audio
PlayRecord PlayRecord_Entity(
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

// Inizializzazione adattatore monitor VGA
vga_adapter VGA_Adapter_Entity(
	.resetn(!reset),
	.clock(CLOCK_50),
	.colour(vga_color),
	.x(vga_x),
	.y(vga_y),
	.plot(vga_plot),
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_HS(VGA_HS),
	.VGA_VS(VGA_VS),
	.VGA_BLANK(VGA_BLANK),
	.VGA_SYNC(VGA_SYNC),
	.clock_25(VGA_CLK)
	);

// Modulo che gestisce il display su monitor VGA
Display Display_Entity(
	CLOCK_50,
	reset,
	pause_Cmd,
	display_data_scaled,
	vga_x,
	vga_y,
	vga_color,
	vga_plot
	);
	
// Convertitori da Binario a BCD
BinaryToBcd SecondsCounter(
	secondsCounter, 
	secondsCounter0, 
	secondsCounter1, 
	secondsCounter2
	);

BinaryToBcd SecondsMax(
	seconds_max, 
	seconds_max0, 
	seconds_max1, 
	seconds_max2
	);

// I display a 7 segmenti 0 e 1 sono usati per visualizzare l'indirizzo della RAM o dei secondi (in rec o play)
hex2seg h0_Entity(
	DisplayRamAddr?  (showMaxAddr? ram_addr_max[17:14]  : ram_addr[17:14])
					:(showMaxAddr? seconds_max0 		: secondsCounter0), 
	HEX0
	);
	
hex2seg h1_Entity(
	DisplayRamAddr?  (showMaxAddr? ram_addr_max[21:18]	: ram_addr[21:18])
					:(showMaxAddr? seconds_max1 		: secondsCounter1), 
	HEX1
	);
	
// Il display a 7 segmenti 2 e' usato per visualizzare il fattore di scala dell'onda sul monitor VGA
hex2seg h4_Entity(
	{2'b00, scale},
	HEX2
	);

// Il display a 7 segmenti 3 viene usato per visualizzare la velocita di riproduzione
hex2seg h3_Entity(
	{2'b00, speed}, 
	HEX3
	);

endmodule