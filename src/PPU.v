module PPU (
    input wire [15:0] addr_in,
    output reg [15:0] addr_out,
    input wire [7:0] data_in,
    output reg [7:0] data_out,
    input wire wen, ren,
    output reg wout, rout // DMA external bus control, takes priority over CPU control
);

    `include "RegMap.vh"
    // Registers
    //bit     7           6           5           4           3           2           1           0

    
    //  | LCD_EN    |  WIN_MAP  |  WIN_EN   |  TILE_SEL |   BG_MAP  | OBJ_SIZE  |  OBJ_EN   |   BG_EN   |
    //  |                                              R/W                                              |  
    reg [7:0] LCDC_reg = 8'b0;

    //  |     -     | INTR_LYC  |  INTR_M2  |  INTR_M1  |  INTR_M0  | LYC_STAT  |       LCD_MODE        |
    //  |     U     |                      R/W                      |                 R                 |
    reg [7:0] STAT_reg = 8'b0;   

    //  |                                              SCY                                              |
    //  |                                              R/W                                              |
    reg [7:0] SCY_reg = 8'b0;  

    //  |                                              SCX                                              |
    //  |                                              R/W                                              |
    reg [7:0] SCX_reg = 8'b0;

    //  |                                              LY                                               |
    //  |                                               R                                               |
    reg [7:0] LY_reg = 8'b0;

    //  |                                              LYC                                              |
    //  |                                              R/W                                              |
    reg [7:0] LYC_reg = 8'b0;

    //  |                                              DMA                                              |
    //  |                                              R/W                                              |
    reg [7:0] DMA_reg = 8'b0; // unspecified startup value

    //  |                                               WX                                              |
    //  |                                              R/W                                              |
    reg [7:0] WX_reg = 8'b0; // cant find much documentation

    //  |                                               WY                                              |
    //  |                                              R/W                                              |
    reg [7:0] WY_reg = 8'b0; // cant find much documentation


    reg [7:0] vram_bank_0 [0:'h1FFF], vram_bank_1 [0:'h1FFF];
    reg [7:0] hram_OAM [0:159];

    reg [8:0] dot_counter;
    reg [7:0] line_counter;
    reg [8:0] mode_len;

    localparam oamScan = 2'd2;
    localparam drawing = 2'd3;
    localparam h_blank = 2'd0;
    localparam v_blank = 2'd1;
endmodule