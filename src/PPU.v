module PPU (
    
);

    reg [7:0] vram_bank_0 [0:'h1FFF], vram_bank_1 [0:'h1FFF];
    reg [7:0] hram_OAM [0:159];
endmodule