`default_nettype none
module Joypad (
	input wire clk, en, rst,
	input wire [15:0] addr,
	input wire [7:0] din,
	output reg [7:0] dout,
	input wire we, re,
	output reg joyp_intr,

	output reg select_buttons, select_dpad,
	input wire start_or_down, select_or_up,
	input wire b_or_left, a_or_right
);

	`include "RegMap.vh"

    //  |     7     |     6     |     5     |     4     |     3     |     2     |     1     |     0     |
    //  |     -     |     -     |  SEL_BTN  |  SEL_DPD  |  START_D  | SELECT_U  |   B_LEFT  |  A_RIGHT  |
    reg [7:0] JOYP_reg = 8'b11_00_1111, JOYP_reg_n;

	always @* begin
		JOYP_reg_n = {JOYP_reg[7:4], start_or_down, select_or_up, b_or_left, a_or_right};
		dout = 8'b0;
		joyp_intr = |(~JOYP_reg[3:0]);
		select_buttons = JOYP_reg[5];
		select_dpad = JOYP_reg[4];
		if ( we == 1'b1 && addr == JOYP ) begin
			JOYP_reg_n[5:4] = din[5:4];
		end
		if ( re == 1'b1 && addr == JOYP ) begin
			dout = JOYP_reg;
		end
	end

	always @ ( posedge clk ) begin
		if ( rst ) begin
			JOYP_reg <= 8'b11_00_1111;
		end
		else if ( en ) begin
			JOYP_reg <= JOYP_reg_n;
		end
	end

endmodule