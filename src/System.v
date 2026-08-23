`timescale 1ns/1ps
`default_nettype none
// `define DEBUG
// `define CART_MODULE
module System (
    `ifdef DEBUG
    output wire dbg_break,
    `endif
    `ifndef CART_MODULE
    output wire [15:0] addr_line,
    output wire [7:0] soc_to_cart_data,
    input wire [7:0] cart_to_soc_data,
    output wire cart_re, cart_we,
    `endif
    input wire clk, rst,
    output wire hsync, vsync, de,
    output wire [4:0] r, g, b,
    output wire [5:0] dac_l, dac_r,
    // input wire done
    input wire sck_i, sdi,
    output wire sck_o, sdo,

    output wire select_buttons, select_dpad,
	input wire start_or_down, select_or_up,
	input wire b_or_left, a_or_right

);
    `ifdef CART_MODULE
    wire [7:0] soc_to_cart_data, cart_to_soc_data;
    wire [15:0] addr_line;
    wire cart_re, cart_we;
    `endif

    wire pix_de;
    wire dotclk;
    assign de = pix_de & dotclk;

    SoC #(
        .clk_frq(4_000_000)
    ) Gameboy_SOC (
        `ifdef DEBUG
        .dbg_break(dbg_break),
        `endif
        .clk(clk), .rst(rst),
        .din(cart_to_soc_data), .dout(soc_to_cart_data),
        .addrbus(addr_line),
        .write_mem(cart_we), .read_mem(cart_re),
        .hsync(hsync), .vsync(vsync), .de(pix_de),
        .dotclk_en(dotclk),
        .r(r), .g(g), .b(b),
        .dac_l(dac_l), .dac_r(dac_r),
        .sck_i(sck_i), .sck_o(sck_o),
        .sdi(sdi), .sdo(sdo),
        .select_buttons(select_buttons), .select_dpad(select_dpad),
        .start_or_down(start_or_down), .select_or_up(select_or_up), 
        .b_or_left(b_or_left), .a_or_right(a_or_right)
    );

    `ifdef CART_MODULE
    MBC #(
        .mbc_type(0),
        .ROMFILE("roms/main.mem")
    ) Cartridge (
        .clk(clk), .rst(rst), .en(1'b1),
        .addr(addr_line),
        .din(soc_to_cart_data), .dout(cart_to_soc_data),
        .re(cart_re), .we(cart_we)
    );
    `endif

    initial begin
        $dumpfile("_out/dump.fst");
        $dumpvars(0, System);
    end



endmodule