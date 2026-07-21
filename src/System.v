`default_nettype none
module System (
    input wire clk, rst,
    output wire hsync, vsync, de,
    output wire [4:0] r, g, b
);

    wire [7:0] soc_to_cart_data, cart_to_soc_data;
    wire [15:0] addr_line;
    wire cart_re, cart_we;

    wire pix_de;
    wire dotclk;
    assign de = pix_de & dotclk;

    SoC Gameboy_SOC (
        .clk(clk), .rst(rst),
        .din(cart_to_soc_data), .dout(soc_to_cart_data),
        .addrbus(addr_line),
        .write_mem(cart_we), .read_mem(cart_re),
        .hsync(hsync), .vsync(vsync), .de(pix_de),
        .dotclk_en(dotclk),
        .r(r), .g(g), .b(b)
    );

    MBC #(
        .type(0),
        .ROMFILE("asteroids.mem")
    ) Cartridge (
        .clk(clk), .rst(rst), .en(1'b1),
        .addr(addr_line),
        .din(soc_to_cart_data), .dout(cart_to_soc_data),
        .re(cart_re), .we(cart_we)
    );

endmodule