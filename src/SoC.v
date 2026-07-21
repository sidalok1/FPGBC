`default_nettype none
module SoC ( 
    input wire clk,
    input wire rst,

    input wire [7:0] din,
    output wire [7:0] dout,
    output wire [15:0] addrbus,
    output wire write_mem,
    output wire read_mem,

    output wire hsync, vsync,
    output wire [4:0] r, g, b,
    output wire de,
    output wire dotclk_en
);

    wire [7:0] sig_cpu_din, sig_cpu_dout;
    wire [15:0] sig_cpu_addrbus;
    wire sig_cpu_we, sig_cpu_re;
    wire [4:0] sig_cpu_intr_req;
    wire sig_cpu_dbl_spd;
    wire sig_cpu_stop;

    wire [15:0] sig_ppu_addri, sig_ppu_addro;
    wire [7:0] sig_ppu_din, sig_ppu_dout;
    wire sig_ppu_wout, sig_ppu_rout;

    wire [7:0] sig_mac_cpu_din, sig_mac_ppu_din;

    ClockDivider #(
        .I_CLK_FRQ(100_000_000),
        .O_CLK_FRQ(4_000_000)
    ) system_clock_divider (
        .rst( rst ), .en( ~sig_cpu_stop ),
        .i_clk( clk ),
        .o_clk( dotclk_en )
    );

    Core cpu_core (
        .clk(clk), .rst(rst), .en(dotclk_en),
        .din(sig_cpu_din), .dout(sig_cpu_dout),
        .addrbus(sig_cpu_addrbus),
        .we(sig_cpu_we), .re(sig_cpu_re),
        .intr_req(sig_cpu_intr_req),
        .dbl_spd(sig_cpu_dbl_spd),
        .stop(sig_cpu_stop)
    );

    PPU pixel_processing_unit (
        .clk(clk), .rst(rst), .en(dotclk_en),
        .addr_in(sig_ppu_addri), .addr_out(sig_ppu_addro),
        .data_in(sig_ppu_din), .data_out(sig_ppu_dout),
        .wen(sig_cpu_we), .ren(sig_cpu_re),
        .dbl_spd(sig_cpu_dbl_spd),
        .wout(sig_ppu_wout),
        .rout(sig_ppu_rout),
        .hsync(hsync), .vsync(vsync),
        .r(r), .g(g), .b(b),
        .de(de)
    );

    MAC memory_access_controller (
        .clk(clk), .rst(rst), .en(dotclk_en),
        .cpu_re(sig_cpu_re), .cpu_we(sig_cpu_we),
        .cpu_addr(sig_cpu_addrbus), .cpu_dout(sig_cpu_dout), .cpu_din(sig_mac_cpu_din),
        .ppu_re(sig_ppu_rout), .ppu_addr(sig_ppu_addro), .ppu_din(sig_mac_ppu_din),
        .cart_addr(addrbus), .cart_we(write_mem), .cart_re(read_mem), .cart_din(dout),
        .cart_dout(din)
    );

    assign sig_cpu_din = sig_ppu_dout | sig_mac_cpu_din;
    assign sig_ppu_din = sig_ppu_rout ? sig_mac_ppu_din : sig_cpu_dout;

endmodule