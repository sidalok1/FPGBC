`default_nettype none
module Serial (
	input wire clk, en, rst,
	input wire [15:0] addr,
	input wire [7:0] din,
	output reg [7:0] dout,
	input wire we, re,
	input wire sck_i,
	output reg sck_o,
	output wire sdo,
	input wire sdi,
	output reg seri_intr
);
	// CPOL = 0, CPHA = 0
	`include "RegMap.vh"

	// Register reads serviced at all times, but writes are commited only in idle state

	//  |                                               SB                                              |
    //  |                                              R/W                                              |
    reg [7:0] SB_reg = 8'b0;  
	reg [7:0] SB_reg_n;

	//  |                                               SC                                              |
    //  |                                              R/W                                              |
    reg [7:0] SC_reg = 8'b0;  
	reg [7:0] SC_reg_n;
	wire TRANSFER_EN = SC_reg[7];
	wire CLOCK_SPEED = SC_reg[1];
	wire CLCK_SELECT = SC_reg[0];

	// For CLOCK_SPEED = 0, the serial clock follows bit 6, and for CLOCK_SPEED = 1 the serial clock 
	// follows bit 1
	reg [6:0] divider = 0, divider_n;
	wire low_speed_clock = divider[6];
	wire high_speed_clock = divider[1];

	reg sdo_reg = 0, sdo_reg_n;
	assign sdo = sdo_reg;
	
	reg sck_reg = 0, sck_reg_n;

	reg posedge_detected, negedge_detected;


	localparam IDLE = 3'b001;
	localparam CONT = 3'b010;
	localparam PERI = 3'b100;
	reg [2:0] state = IDLE, state_n;
	reg [2:0] count = 0, count_n;

	always @ ( posedge clk ) begin
		if ( rst ) begin
			SB_reg <= 0;
			SC_reg <= 0;
			divider <= 0;
			state <= IDLE;
			sck_reg <= 0;
			count <= 0;
			sdo_reg <= 0;
		end
		else 
		if ( en | we ) begin
			SB_reg <= SB_reg_n;
			SC_reg <= SC_reg_n;
			if ( en ) begin // only on cpu en
				divider <= divider_n;
				sck_reg <= sck_reg_n;
				state <= state_n;
				count <= count_n;
				sdo_reg <= sdo_reg_n;
			end
		end
	end

	always @* begin
		seri_intr = 0;
		divider_n = 0;
		SB_reg_n = SB_reg;
		SC_reg_n = SC_reg;
		sck_reg_n = 0;
		sdo_reg_n = sdo_reg;
		dout = 0;
		state_n = state;
		count_n = count;

		
		sck_o = CLOCK_SPEED ? high_speed_clock : low_speed_clock;
		negedge_detected = CLCK_SELECT ? 
			(~sck_o & sck_reg) :
			(~sck_i & sck_reg);
		posedge_detected = CLCK_SELECT ?
			(sck_o & ~sck_reg) :
			(sck_i & ~sck_reg);
		sck_reg_n = CLCK_SELECT ?
			sck_o :
			sck_i;
		
		// sck_o = 0;

		if ( ~TRANSFER_EN ) begin // awaiting transfer
			if ( we )
			case ( addr )
				SB: SB_reg_n = din;
				SC: SC_reg_n = din;
				default:; //
			endcase
			if ( SC_reg_n[7] ) begin // transfer requested
				count_n = 0;
				sdo_reg_n = SB_reg[7];
			end
		end
		else begin
			divider_n = divider + 1;
			if ( negedge_detected ) begin
				sdo_reg_n = SB_reg[7];
				if ( count == 'd7 ) begin
					SC_reg_n[7] = 0; // end transfer
					seri_intr = 1; // and issue intr
					count_n = 0;
				end
				else
					count_n = count + 1;
			end
			if ( posedge_detected ) begin
				SB_reg_n = {SB_reg[6:0], sdi};	
			end
		end

		if ( re ) begin
			case ( addr )
				SB: dout = SB_reg;
				SC: dout = SC_reg;
				default:;//
			endcase
		end

	end



endmodule