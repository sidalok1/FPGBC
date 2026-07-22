`default_nettype none
module MAC(
    input wire clk, rst, en,
    input wire cpu_re, cpu_we, ppu_re,
    input wire [15:0] cpu_addr, ppu_addr,
    input wire [7:0] cpu_dout,
    output reg [7:0] cpu_din, ppu_din,
    output reg [15:0] cart_addr,
    input wire [7:0] cart_dout,
    output reg [7:0] cart_din,
    output reg cart_re, cart_we
);

    `include "RegMap.vh"

    // Memory access controller
    // For the bootrom, WRAM, and cartridge
    // VRAM and OAM are defined in the PPU mod
    // HRAM is defined in the CPU core mod

    //  |                                             BANK                                              |
    //  |                                              R/O                                              |
    reg [7:0] BANK_reg = 8'h00; // Written to once by boot rom
    reg BANK_lock = 0;

    //  |                                             SVBK                                              |
    //  |                                              R/W                                              |
    reg [7:0] SVBK_reg = 8'h00;

    reg [7:0] bootrom [0:2047 + 'h100];
    reg [11:0] bootrom_addr;
    wire [7:0] bootrom_data = bootrom[bootrom_addr];


    reg [7:0] wram [0:7][0:4095]; // Eight banks of WRAM, selected with SVBK. Bank 0 always accessible
    reg [11:0] wram_addr;
    reg [2:0] wram_bank_sel; // value of 0 selects bank 1
    reg wram_we;
    reg [7:0] wram_din;
    wire [7:0] wram_dout = wram[wram_bank_sel][wram_addr];

    reg cpu_addr_in_bootrom;
    reg ppu_addr_in_wram, cpu_addr_in_wram;
    reg ppu_addr_in_wram_banked, cpu_addr_in_wram_banked;
    reg ppu_addr_in_cart, cpu_addr_in_cart;

    initial begin
        $readmemh("roms/cgb_boot.mem", bootrom);
    end


    always @ ( posedge clk ) begin
        if ( rst ) begin
            BANK_reg <= 0;
            BANK_lock <= 0;
            SVBK_reg <= 0;
        end
        else if ( en ) begin
            if ( wram_we )
                wram[wram_bank_sel][wram_addr] <= wram_din;
            if ( cpu_we ) begin
                case ( cpu_addr )
                BANK: begin
                    if ( !BANK_lock ) begin
                        BANK_lock <= 1;
                        BANK_reg <= cpu_dout;
                    end
                end
                SVBK: SVBK_reg <= cpu_dout;
                default:; // all other writes handled by other logic
                endcase
            end
        end
    end

    always @* begin
        bootrom_addr = 0;
        wram_addr = 0;
        wram_bank_sel = 0;
        wram_din = 0;
        wram_we = 0;
        cart_addr = cpu_addr;
        cart_re = 0;
        cart_we = 0;
        cart_din = 0;

        cpu_din = 8'h00;
        ppu_din = 8'h00;

        cpu_addr_in_bootrom =   (cpu_addr >= 16'h0000 && cpu_addr <= 16'h08FF);
        cpu_addr_in_wram = cpu_addr >= 16'hC000 && cpu_addr <= 16'hCFFF;
        ppu_addr_in_wram = ppu_addr >= 16'hC000 && ppu_addr <= 16'hCFFF;
        cpu_addr_in_wram_banked = cpu_addr >= 16'hD000 && cpu_addr <= 16'hDFFF;
        ppu_addr_in_wram_banked = ppu_addr >= 16'hD000 && ppu_addr <= 16'hDFFF;
        cpu_addr_in_cart =  (cpu_addr >= 16'h0000 && cpu_addr <= 16'h7FFF) ||
                            (cpu_addr >= 16'hA000 && cpu_addr <= 16'hBFFF);
        ppu_addr_in_cart =  (ppu_addr >= 16'h0000 && ppu_addr <= 16'h7FFF) ||
                            (ppu_addr >= 16'hA000 && ppu_addr <= 16'hBFFF);

        if ( cpu_addr_in_wram ) begin
            wram_we = cpu_we;
            wram_addr = cpu_addr - 16'hC000;
            wram_bank_sel = 0;
        end
        else if ( cpu_addr_in_wram_banked ) begin
            wram_addr = cpu_addr - 16'hD000;
            wram_we = cpu_we;
            wram_bank_sel = (SVBK_reg[2:0] == 0) ? 1 : SVBK_reg[2:0];
        end
        else if ( cpu_addr_in_cart ) begin
            if ( BANK_lock == 0 && cpu_addr_in_bootrom )
                bootrom_addr = cpu_addr;
            else begin
                cart_addr = cpu_addr;
                cart_we = cpu_we;
            end
        end

        if ( cpu_re ) begin
            if ( cpu_addr == BANK )
                cpu_din = BANK_reg;
            else if ( cpu_addr == SVBK )
                cpu_din = SVBK_reg;
            else if ( cpu_addr_in_wram || cpu_addr_in_wram_banked ) begin
                cpu_din = wram_dout;
            end
            else if ( cpu_addr_in_cart ) begin
                if ( BANK_lock == 0 && cpu_addr_in_bootrom )
                    cpu_din = bootrom_data;
                else
                    cpu_din = cart_dout;
            end
        end

        if ( cpu_we ) begin
            if ( cpu_addr_in_wram || cpu_addr_in_wram_banked ) begin
                wram_we = 1;
                wram_din = cpu_dout;
            end
            else if ( cpu_addr_in_cart ) begin
                if ( !BANK_lock ) begin
                    cart_we = 1;
                    cart_din = cpu_dout;
                end
            end
        end
        

        if ( ppu_re ) begin
            if ( ppu_addr_in_wram ) begin
                wram_we = 0;
                wram_bank_sel = 0;
                wram_addr = ppu_addr - 16'hC000;
                ppu_din = wram_dout;
            end
            else if ( ppu_addr_in_wram_banked ) begin
                wram_we = 0;
                wram_bank_sel = SVBK_reg[2:0] == 0 ? 1 : SVBK_reg[2:0];
                wram_addr = ppu_addr - 16'hD000;
                ppu_din = wram_dout;
            end
            else if ( ppu_addr_in_cart ) begin
                cart_addr = ppu_addr;
                cart_we = 0;
                cart_re = 1;
                ppu_din = cart_dout;
            end
        end
        
    end


endmodule