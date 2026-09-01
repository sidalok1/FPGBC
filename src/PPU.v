`default_nettype none
module PPU (
    input wire clk, rst, en, cpu_en,

    input wire [15:0] addr_in,
    output reg [15:0] addr_out,
    input wire [7:0] data_in,
    output reg [7:0] data_out,
    input wire [7:0] dma_data_in,
    input wire wen, ren,
    input wire dbl_spd,
    output reg wout, rout,

    output reg hsync, vsync,
    output reg [4:0] r, g, b,
    output reg de,
    output reg stat_intr,
    output reg vblank_intr,
    output wire [1:0] LCD_mode
);

    `include "RegMap.vh"
    // Registers
    //bit     7           6           5           4           3           2           1           0

    
    //  | LCD_EN    |  WIN_MAP  |  WIN_EN   |  TILE_SEL |   BG_MAP  | OBJ_SIZE  |  OBJ_EN   |   BG_EN   |
    //  |                                              R/W                                              |  
    reg [7:0] LCDC_reg = 8'h00;
    reg [7:0] LCDC_reg_n;
    wire LCD_EN, WIN_MAP, WIN_EN, TILE_SEL, BG_MAP, OBJ_SIZE, OBJ_EN, BG_EN;
    assign {LCD_EN, WIN_MAP, WIN_EN, TILE_SEL, BG_MAP, OBJ_SIZE, OBJ_EN, BG_EN} = LCDC_reg;

    //  |     -     | INTR_LYC  |  INTR_M2  |  INTR_M1  |  INTR_M0  | LYC_STAT  |       LCD_MODE        |
    //  |     U     |                      R/W                      |                 R                 |
    reg [7:0] STAT_reg = 8'h82;
    reg [7:0] STAT_reg_n;
    wire INTR_LYC_EN, INTR_M2_EN, INTR_M1_EN, INTR_M0_EN, LY_EQ_LYC;
    assign {INTR_LYC_EN, INTR_M2_EN, INTR_M1_EN, INTR_M0_EN, LY_EQ_LYC, LCD_mode} = STAT_reg[6:0];
    //  |                                              SCY                                              |
    //  |                                              R/W                                              |
    reg [7:0] SCY_reg = 8'b0;
    reg [7:0] SCY_reg_n;  

    //  |                                              SCX                                              |
    //  |                                              R/W                                              |
    reg [7:0] SCX_reg = 8'b0;
    reg [7:0] SCX_reg_n;

    //  |                                              LY                                               |
    //  |                                               R                                               |
    reg [7:0] LY_reg = 8'b0;
    reg [7:0] LY_reg_n;
    // reg inc_LY;

    //  |                                              LYC                                              |
    //  |                                              R/W                                              |
    reg [7:0] LYC_reg = 8'b0;
    reg [7:0] LYC_reg_n;

    //  |                                              DMA                                              |
    //  |                                              R/W                                              |
    reg [7:0] DMA_reg = 8'b0; // unspecified startup value
    reg [7:0] DMA_reg_n;

    //  |                                              BGP                                              |
    //  |                                              R/W                                              |
    reg [7:0] BGP_reg = 8'b0;
    reg [7:0] BGP_reg_n;

    //  |                                             OBP0                                              |
    //  |                                              R/W                                              |
    reg [7:0] OBP0_reg = 8'b0;
    reg [7:0] OBP0_reg_n; 

    //  |                                             OBP1                                              |
    //  |                                              R/W                                              |
    reg [7:0] OBP1_reg = 8'b0;
    reg [7:0] OBP1_reg_n; 

    //  |                                               WX                                              |
    //  |                                              R/W                                              |
    reg [7:0] WX_reg = 8'b0;
    reg [7:0] WX_reg_n;

    //  |                                               WY                                              |
    //  |                                              R/W                                              |
    reg [7:0] WY_reg = 8'b0;
    reg [7:0] WY_reg_n;

    //  |     ?     |     ?     |     ?     |     ?     |     ?     | DMG_MODE  |     ?     |     ?     |
    //  |                                                R                                              |
    // writes lock after first write to BANK
    reg [7:0] KEY0_reg = 8'h00;
    reg [7:0] KEY0_reg_n;
    reg KEY0_locked = 0;
    reg KEY0_locked_n;
    wire DMG_mode = KEY0_reg[2];

    //  |                                              VBK                                              |
    //  |                                              R/W                                              |
    reg [7:0] VBK_reg = 8'hFE; // reads return {7'b1, [VRAM BANK NUMBER]}
    reg [7:0] VBK_reg_n;

    //  | AUTO_INC  |     -     |                              BGP_ADDR                                 |
    //  |                                              R/W                                              |
    reg [7:0] BGPI_reg = 8'hC0;
    reg [7:0] BGPI_reg_n;
    wire BGP_AUTO_INC = BGPI_reg[7];
    wire [5:0] BGP_ADDR = BGPI_reg[5:0];

    //  |                                             BGPD                                              |
    //  |                                              R/W                                              |
    // reg [7:0] BGPD_reg;

    //  | AUTO_INC  |     -     |                              OBP_ADDR                                 |
    //  |                                              R/W                                              |
    reg [7:0] OBPI_reg = 8'hC0;
    reg [7:0] OBPI_reg_n;
    wire OBP_AUTO_INC = OBPI_reg[7];
    wire [5:0] OBP_ADDR = OBPI_reg[5:0];
    //  |                                             OBPD                                              |
    //  |                                              R/W                                              |
    // reg [7:0] OBPD_reg;

    //  |     ?     |     ?     |     ?     |     ?     |     ?     |     ?     |     ?     |  PRI_MODE |
    //  |                                              R/W                                              |
    // Online documentation seems to suggest that this register locks after unmapping the boot rom. I am
    // for now keeping it unlocked.
    reg [7:0] OPRI_reg = 8'hFE;
    reg [7:0] OPRI_reg_n;
    wire OBJ_PRI_MODE = OPRI_reg[0];

    reg [7:0] vram_bank_0 [0:'h1FFF], vram_bank_1 [0:'h1FFF];
    reg vram0_we, vram1_we;
    reg [12:0] vram_addr;
    reg [7:0] vram_din;
    wire [7:0] vram0_dout = vram_bank_0[vram_addr];
    wire [7:0] vram1_dout = DMG_mode ? 8'h00 : vram_bank_1[vram_addr];
    reg addr_in_is_vram;
    reg [7:0] OAM [0:159];
    reg oam_we;
    reg [7:0] oam_addr;
    reg [7:0] oam_din;
    wire [7:0] oam_dout = OAM[oam_addr];
    reg addr_in_is_oam;

    reg [8:0] dot_counter = 0, dot_counter_n;
    reg [3:0] objs_on_scanline = 0, objs_on_scanline_n;
    reg [7:0] oam_idx = 0, oam_idx_n;

    reg [7:0] obj_arr [0:9][0:4]; // ypos, xpos, tile, attr, obj num
    reg [9:0] obj_valid = 0, obj_valid_n, obj_x_hit;
    reg [3:0] current_obj = 0, current_obj_n;
    wire [3:0] obj_with_priority;
    wire obj_priority_valid;
    PriorityEncoder10 obj_priority_encoder (
        .i(obj_valid & obj_x_hit),
        .o(obj_with_priority),
        .v(obj_priority_valid)
    );
    wire [7:0] obj_y = obj_arr[current_obj][0];
    // wire [7:0] obj_x = obj_arr[current_obj][1]; unused
    wire [7:0] obj_tile = (OBJ_SIZE == 0) ? obj_arr[current_obj][2] : obj_arr[current_obj][2] & 8'hFE;
    wire [7:0] obj_attr = obj_arr[current_obj][3];
    wire [7:0] obj_addr = obj_arr[current_obj][4];
    
    reg write_obj_arr;
    reg [1:0] obj_arr_elem;
    reg [7:0] obj_arr_data;

    reg [7:0] obj_height;
    reg obj_is_on_line;

    // PPU states
    localparam oamScan = 2'd2;

        // Mode 2 substates
        localparam get_y_position = 'b00001;
        localparam get_x_position = 'b00010;
        localparam get_obj_tile   = 'b00100;
        localparam get_obj_attr   = 'b01000;
        localparam await_mode_3   = 'b10000;
    reg [4:0] oamScan_substate, oamScan_substate_n;

    localparam drawing = 2'd3;

        // Mode 3 substates
        localparam fetcher_bgr_map_addr     = 'b001_000001;
        localparam fetcher_bgr_read_map     = 'b001_000010;
        localparam fetcher_bgr_data_addr    = 'b001_000100;
        localparam fetcher_bgr_low_data     = 'b001_001000;
        localparam fetcher_bgr_high_data    = 'b001_010000;
        localparam fetcher_bgr_push_fifo    = 'b001_100000;
        localparam fetcher_win_map_addr     = 'b010_000001;
        localparam fetcher_win_read_map     = 'b010_000010;
        localparam fetcher_win_data_addr    = 'b010_000100;
        localparam fetcher_win_low_data     = 'b010_001000;
        localparam fetcher_win_high_data    = 'b010_010000;
        localparam fetcher_win_push_fifo    = 'b010_100000;
        localparam fetcher_obj_wait         = 'b100_000001;
        localparam fetcher_obj_data_addr    = 'b100_000010;
        localparam fetcher_obj_low_data     = 'b100_000100;
        localparam fetcher_obj_high_data    = 'b100_001000;
        localparam fetcher_obj_merge_fifo   = 'b100_010000;
        localparam fetcher_obj_push_fifo    = 'b100_100000;
        reg [8:0] fetcher_state = fetcher_bgr_map_addr, fetcher_state_n;
        reg [8:0] fetcher_return = fetcher_bgr_map_addr, fetcher_return_n;

        wire bgr_state = fetcher_state[6];
        wire win_state = fetcher_state[7];
        wire obj_state = fetcher_state[8];

        reg [5:0] bgr_fifo [0:7]; // {color_index[5:4], palette_num[3:1], priority[0]}
        wire [1:0] bgr_pix_idx = bgr_fifo[0][5:4];
        wire [2:0] bgr_pix_pal = bgr_fifo[0][3:1];
        wire bgr_pix_pri = bgr_fifo[0][0];
        reg [3:0] bgr_fifo_len;
        reg bgr_fifo_read;
        reg bgr_fifo_push;
        reg bgr_fifo_flush = 0, bgr_fifo_flush_n;

        reg [7:0] fetch_counter = 0, fetch_counter_n;
        reg [7:0] pix_x;
        reg [7:0] tile_x;
        reg [7:0] pix_y;
        reg [7:0] tile_y; 
        reg [7:0] row_offset;
        reg [12:0] tile_addr = 0, tile_addr_n;
        reg [7:0] tile_attr = 0, tile_attr_n;
        reg [7:0] tile_idx = 0, tile_idx_n;
        reg [7:0] data_low = 0, data_low_n;
        reg [7:0] data_high = 0, data_high_n;

        reg [7:0] win_x = 0, win_x_n;
        reg [7:0] win_y = 0, win_y_n;
        reg win_y_cond = 0, win_y_cond_n;
        reg win_trigger;

        // use of signed enforces the addition operation to take place. using tile_offset
        // will perform operation as signed and using tile_idx will perform unsigned
        reg [12:0] map_base;
        reg signed [12:0] data_base;
        reg [12:0] tile_base;

        reg obj_trigger;
        
        reg [11:0] obj_fifo [0:7]; // {oam_addr[11:6], color_index[5:4], palette_num[3:1], priority[0]}
        wire [1:0] obj_pix_idx = obj_fifo[0][5:4];
        wire [2:0] obj_pix_pal = obj_fifo[0][3:1];
        wire obj_pix_pri = obj_fifo[0][0];
        reg obj_fifo_merge [0:7]; // 1 for each position to be overwritten by merge
        reg obj_fifo_merge_n [0:7];
        reg [7:0] obj_low = 0, obj_low_n, obj_high = 0, obj_high_n;
        reg [3:0] obj_fifo_len;
        reg obj_fifo_flush = 0, obj_fifo_flush_n;
        reg obj_fifo_read;
        reg obj_fifo_push;

        reg [7:0] output_x = 0, output_x_n;
        reg [2:0] discard_x = 0, discard_x_n;
        reg halt_output;
        // same format as fifo pixels, but idx 0 is 0 for background/window and 1 for objects
        reg [5:0] mixed_pixel = 0, mixed_pixel_n, mixed_pixel0 = 0, mixed_pixel0_n;
        reg [3:0] pallet_idx = 0, pallet_idx_n;
        reg [7:0] rgb_low = 0, rgb_low_n, rgb_low0 = 0, rgb_low0_n;
        reg [7:0] rgb_high = 0, rgb_high_n;
        reg [4:0] r_n, g_n, b_n;
        reg de2 = 0, de2_n, de1 = 0, de0 = 0;

        // wire [7:0] DMG_RGB [0:9];
        // assign DMG_RGB[0] = {3'b000, 5'b11000}; // white
        // assign DMG_RGB[1] = {1'b0, 5'b11000, 2'b11};
        // assign DMG_RGB[2] = {3'b000, 5'b10000}; // light gray
        // assign DMG_RGB[3] = {1'b0, 5'b10000, 2'b10};
        // assign DMG_RGB[4] = {3'b000, 5'b01000}; // dark gray
        // assign DMG_RGB[5] = {1'b0, 5'b01000, 2'b01};
        // assign DMG_RGB[6] = {3'b000, 5'b00000}; // black
        // assign DMG_RGB[7] = {1'b0, 5'b00000, 2'b00};
        // assign DMG_RGB[8] = 8'hFF; // blank
        // assign DMG_RGB[9] = 8'hFF;

        reg [7:0] BGP_RGB [0:63];
        reg BGP_RGB_we;
        reg [7:0] OBP_RGB [0:63];
        reg OBP_RGB_we;

    localparam h_blank = 2'd0;
        reg hsync_n;
    localparam v_blank = 2'd1;
        reg vsync_n;
    reg start_DMA = 0, start_DMA_n; 
    reg DMA_state = 0, DMA_state_n;
    reg [7:0] DMA_counter = 0, DMA_counter_n;

    integer i;

    reg [1:0] current_mode;
    reg [1:0] next_mode;

    genvar n;
    generate
        for ( n = 0; n < 8; n = n + 1 ) begin : fifo_slots
            always @ ( posedge clk ) begin
                if ( rst ) begin
                    bgr_fifo[n] <= 0;
                    obj_fifo[n] <= 0;
                end
                else
                if ( en && LCD_EN ) begin
                    // bgr fifo
                    if ( bgr_fifo_flush ) begin
                        bgr_fifo[n] <= 0;
                    end
                    else if ( bgr_fifo_push ) begin
                        if ( tile_attr[5] == 1 )
                            bgr_fifo[n] <= {data_high[n], data_low[n], tile_attr[2:0], tile_attr[7]};
                        else
                            bgr_fifo[n] <= {data_high[7-n], data_low[7-n], tile_attr[2:0], tile_attr[7]};
                    end
                    else if ( bgr_fifo_read ) begin
                        if ( n < 7 )
                            bgr_fifo[n] <= bgr_fifo[n+1];
                    end
                    // obj fifo
                    obj_fifo_merge[n] <= obj_fifo_merge_n[n];
                    if ( obj_fifo_flush ) begin
                        obj_fifo[n] <= 0;
                    end
                    else if ( obj_fifo_push ) begin
                        if ( obj_attr[5] == 1 )
                            if ( !DMG_mode ) begin
                                obj_fifo[n] <= obj_fifo_merge[n] ?
                                    {obj_addr[5:0], obj_high[n], obj_low[n], obj_attr[2:0], obj_attr[7]} :
                                    obj_fifo[n];
                            end
                            else begin
                                obj_fifo[n] <= obj_fifo_merge[n] ?
                                    {obj_addr[5:0], obj_high[n], obj_low[n], 2'b0, obj_attr[4], obj_attr[7]} :
                                    obj_fifo[n];
                            end
                        else
                            if ( !DMG_mode )
                                obj_fifo[n] <= obj_fifo_merge[n] ?
                                    {obj_addr[5:0], obj_high[7-n], obj_low[7-n], obj_attr[2:0], obj_attr[7]} :
                                    obj_fifo[n];
                            else
                                obj_fifo[n] <= obj_fifo_merge[n] ?
                                    {obj_addr[5:0], obj_high[7-n], obj_low[7-n], 2'b0, obj_attr[4], obj_attr[7]} :
                                    obj_fifo[n];
                    end
                    else if ( obj_fifo_read ) begin
                        if ( n < 7 )
                            obj_fifo[n] <= obj_fifo[n+1];
                    end
                end
            end
        end
    endgenerate
    always @ ( posedge clk ) begin
        if ( rst ) begin
            bgr_fifo_len <= 0;
            bgr_fifo_flush <= 0;
            obj_fifo_len <= 0;
            obj_fifo_flush <= 0;
        end
        else if ( en && LCD_EN ) begin
            bgr_fifo_flush <= bgr_fifo_flush_n;
            if ( bgr_fifo_flush )       bgr_fifo_len <= 0;
            else if ( bgr_fifo_push )   bgr_fifo_len <= 8;
            else if ( bgr_fifo_read )   bgr_fifo_len <= (bgr_fifo_len == 0) ? 0 : bgr_fifo_len - 1;

            obj_fifo_flush <= obj_fifo_flush_n;
            if ( obj_fifo_flush )       obj_fifo_len <= 0;
            else if ( obj_fifo_push )   obj_fifo_len <= 8;
            else if ( obj_fifo_read )   obj_fifo_len <= (obj_fifo_len == 0) ? 0 : obj_fifo_len - 1;
        end
    end

    initial begin
        addr_out = 0;
        data_out = 0;
        hsync = 1;
        vsync = 1;
        {r, g, b} = 0;
        de = 0;
        for ( i = 0; i < 'h2000; i = i + 1 ) begin
            vram_bank_0[i] = 0;
            vram_bank_1[i] = 0;
            if ( i < 160 )
                OAM[i] = 0;
            if ( i < 64 ) begin
                BGP_RGB[i] = 0;
                OBP_RGB[i] = 0;
            end
            if ( i < 10 ) begin
                obj_arr[i][0] = 0;
                obj_arr[i][1] = 0;
                obj_arr[i][2] = 0;
                obj_arr[i][3] = 0;
                obj_arr[i][4] = 0;
            end
            if ( i < 8 ) begin
                bgr_fifo[i] = 0;
                obj_fifo[i] = 0;
                obj_fifo_merge[i] = 0;
            end
        end
    end

    always @ ( posedge clk ) begin 
        if ( rst ) begin
            DMA_state <= 0;
            start_DMA <= 0;
            DMA_counter <= 0;
            current_mode <= h_blank;
            dot_counter <= 0;
            oamScan_substate <= get_y_position;
            oam_idx <= 0;
            for ( i = 0; i < 10; i = i + 1 ) begin
                obj_arr[i][0] <= 0;
                obj_arr[i][1] <= 0;
                obj_arr[i][2] <= 0;
                obj_arr[i][3] <= 0;
                obj_arr[i][4] <= 0;
            end
            obj_valid <= 0;
            objs_on_scanline <= 0;
            current_obj <= 0;
            fetcher_state <= fetcher_bgr_map_addr;
            fetcher_return <= fetcher_bgr_map_addr;
            fetch_counter <= 0;
            tile_addr <= 0;
            tile_idx <= 0;
            tile_attr <= 0;
            data_low <= 0;
            data_high <= 0;
            win_y_cond <= 0;
            win_x <= 0;
            win_y <= 0;
            obj_low <= 0;
            obj_high <= 0;
            output_x <= 0;
            discard_x <= 0;
            mixed_pixel <= 0;
            mixed_pixel0 <= 0;
            rgb_low <= 0;
            rgb_low0 <= 0;
            pallet_idx <= 0;
            rgb_high <= 0;
            r <= 0;
            g <= 0;
            b <= 0;
            de <= 0;
            de0 <= 0;
            de1 <= 0;
            de2 <= 0;
            hsync <= 1;
            vsync <= 1;
            LY_reg <= 0;
            LCDC_reg <= 8'h00;
            STAT_reg[7:3] <= 5'b10000;
            SCY_reg <= 0;
            SCX_reg <= 0;
            LYC_reg <= 0;
            DMA_reg <= 0;
            BGP_reg <= 0;
            OBP0_reg <= 0;
            OBP1_reg <= 0;
            WX_reg <= 0;
            WY_reg <= 0;
            KEY0_reg <= 0;
            KEY0_locked <= 0;
            BGPI_reg <= 8'hC0;
            OBPI_reg <= 8'hC0;
            OPRI_reg <= 8'hFE;
            VBK_reg <= 8'hFE;
        end
        else
        if ( en ) begin
            LCDC_reg <= LCDC_reg_n;
            STAT_reg <= STAT_reg_n;
            SCY_reg <= SCY_reg_n;
            SCX_reg <= SCX_reg_n;
            LY_reg <= LY_reg_n;
            LYC_reg <= LYC_reg_n;
            DMA_reg <= DMA_reg_n;
            BGP_reg <= BGP_reg_n;
            OBP0_reg <= OBP0_reg_n;
            OBP1_reg <= OBP1_reg_n;
            WX_reg <= WX_reg_n;
            WY_reg <= WY_reg_n;
            KEY0_reg <= KEY0_reg_n;
            KEY0_locked <= KEY0_locked_n;
            VBK_reg <= VBK_reg_n;
            BGPI_reg <= BGPI_reg_n;
            OBPI_reg <= OBPI_reg_n;
            OPRI_reg <= OPRI_reg_n;

            if ( cpu_en ) begin
                start_DMA <= start_DMA_n;
                DMA_state <= DMA_state_n;
                DMA_counter <= DMA_counter_n;
            end
            if ( oam_we )
                OAM[oam_addr] <= oam_din;
            if ( vram0_we )
                vram_bank_0[vram_addr] <= vram_din;
            if ( vram1_we )
                vram_bank_1[vram_addr] <= vram_din;
            if ( BGP_RGB_we )
                BGP_RGB[BGP_ADDR] <= data_in;
            if ( OBP_RGB_we )
                OBP_RGB[OBP_ADDR] <= data_in;
            if ( LCD_EN ) begin
                current_mode <= next_mode;
                dot_counter <= dot_counter_n;
                oamScan_substate <= oamScan_substate_n;
                oam_idx <= oam_idx_n;
                if ( write_obj_arr ) begin
                    obj_arr[objs_on_scanline][{1'b0, obj_arr_elem}] <= obj_arr_data;
                    if ( obj_arr_elem == 0 ) // adding new element to object array
                        obj_arr[objs_on_scanline][4] <= oam_idx / 4; // position in OAM
                end
                obj_valid <= obj_valid_n;
                objs_on_scanline <= objs_on_scanline_n;
                current_obj <= current_obj_n;
                fetcher_state <= fetcher_state_n;
                fetcher_return <= fetcher_return_n;
                fetch_counter <= fetch_counter_n;
                tile_addr <= tile_addr_n;
                tile_idx <= tile_idx_n;
                tile_attr <= tile_attr_n;
                data_low <= data_low_n;
                data_high <= data_high_n;
                win_y_cond <= win_y_cond_n;
                win_x <= win_x_n;
                win_y <= win_y_n;
            
                obj_low <= obj_low_n;
                obj_high <= obj_high_n;

                output_x <= output_x_n;
                discard_x <= discard_x_n;

                mixed_pixel <= mixed_pixel_n;
                mixed_pixel0 <= mixed_pixel0_n;
                rgb_low <= rgb_low_n;
                rgb_low0 <= rgb_low0_n;
                pallet_idx <= pallet_idx_n;
                rgb_high <= rgb_high_n;
                r <= r_n;
                g <= g_n;
                b <= b_n;
                de <= de0;
                de0 <= de1;
                de1 <= de2;
                de2 <= de2_n;
                hsync <= hsync_n;
                vsync <= vsync_n;
            end
        end
    end

    always @* begin
        // defaults (if needed)
        LCDC_reg_n                      = LCDC_reg;
        STAT_reg_n[7:3]                 = STAT_reg[7:3];
        SCY_reg_n                       = SCY_reg;
        SCX_reg_n                       = SCX_reg;
        LY_reg_n                        = LY_reg;
        LYC_reg_n                       = LYC_reg;
        DMA_reg_n                       = DMA_reg;
        BGP_reg_n                       = BGP_reg;
        OBP0_reg_n                      = OBP0_reg;
        OBP1_reg_n                      = OBP1_reg;
        WX_reg_n                        = WX_reg;
        WY_reg_n                        = WY_reg;
        KEY0_reg_n                      = KEY0_reg;
        KEY0_locked_n                   = KEY0_locked;
        VBK_reg_n                       = VBK_reg;
        BGPI_reg_n                      = BGPI_reg;
        BGP_RGB_we                      = 0;
        OBPI_reg_n                      = OBPI_reg;
        OBP_RGB_we                      = 0;
        OPRI_reg_n                      = OPRI_reg;

        stat_intr                       = 0;
        vblank_intr                     = 0;
        oam_din                         = data_in;
        vram_din                        = data_in;
        
        oam_we                          = 0;
        vram0_we                        = 0;
        vram1_we                        = 0;

        DMA_state_n                     = DMA_state;
        DMA_counter_n                   = DMA_counter;
        start_DMA_n                     = 0;
        rout                            = 0;
        wout                            = 0;
        addr_out                        = 0;

        dot_counter_n                   = dot_counter + 1;
        next_mode                       = current_mode;
        oamScan_substate_n              = oamScan_substate;
        oam_idx_n                       = oam_idx;
        addr_in_is_oam = (addr_in >= 16'hFE00) && (addr_in <= 16'hFE9F);
        addr_in_is_vram = (addr_in >= 16'h8000) && (addr_in <= 16'h9FFF);
        if ( addr_in_is_oam )
            oam_addr                    = addr_in[7:0];
        else
            oam_addr                    = 8'b0;
        if ( addr_in_is_vram )
            vram_addr                   = addr_in[12:0];
        else
            vram_addr                   = 13'b0;
        obj_is_on_line                  = 0;
        objs_on_scanline_n              = objs_on_scanline;
        write_obj_arr                   = 0;
        obj_arr_elem                    = 0;
        obj_arr_data                    = 0;
        fetcher_state_n                 = fetcher_state;
        fetcher_return_n                = fetcher_return;
        fetch_counter_n                 = fetch_counter;
        tile_addr_n                     = tile_addr;
        tile_idx_n                      = tile_idx;
        tile_attr_n                     = tile_attr;
        data_low_n                      = data_low;
        data_high_n                     = data_high;
        pix_x                           = 0;
        pix_y                           = 0;
        map_base                        = 0;
        win_y_cond_n                    = win_y_cond;
        win_x_n                         = win_x;
        win_y_n                         = win_y;


        obj_valid_n                     = obj_valid;
        current_obj_n                   = current_obj;
        obj_low_n                       = obj_low;
        obj_high_n                      = obj_high;

        output_x_n                      = output_x;
        discard_x_n                     = discard_x;              
        halt_output                     = 0;

        mixed_pixel_n                   = mixed_pixel;
        mixed_pixel0_n                  = mixed_pixel0;
        rgb_low_n                       = rgb_low;
        rgb_low0_n                      = rgb_low0;
        pallet_idx_n                    = pallet_idx;
        rgb_high_n                      = rgb_high;

        bgr_fifo_flush_n                = 0;
        bgr_fifo_push                   = 0;
        bgr_fifo_read                   = 0;

        for ( i = 0; i < 8; i = i + 1 )
            obj_fifo_merge_n[i]         = obj_fifo_merge[i];
        obj_fifo_flush_n                = 0;
        obj_fifo_push                   = 0;
        obj_fifo_read                   = 0;

        r_n                             = 0;
        g_n                             = 0;
        b_n                             = 0;
        de2_n                           = 0;
        hsync_n                         = 1;
        vsync_n                         = 1;

        STAT_reg_n[2] = LY_reg == LYC_reg;
        if ( INTR_LYC_EN == 1 && LY_reg == LYC_reg )
            stat_intr = 1;
        if ( !LCD_EN ) begin
            STAT_reg_n[1:0] = 0;
        end
        else
            STAT_reg_n[1:0] = current_mode;

        // CPU issued writes have lower priority than both ppu and dma. These combinational
        // values can be later overwritten
        if ( wen ) begin
            case ( addr_in )
                LCDC: LCDC_reg_n =      data_in;
                STAT: STAT_reg_n[6:3] = data_in[6:3];
                SCY:  SCY_reg_n =       data_in;
                SCX:  SCX_reg_n =       data_in;
                // LY is R/O
                LYC:  LYC_reg_n =       data_in;
                DMA: begin
                    // DMA register always written to but should only be triggered with valid
                    // address
                    DMA_reg_n =     data_in;
                    if ( data_in <= 8'hDF ) begin
                        start_DMA_n =   1;
                    end
                    else begin
                        start_DMA_n =   0;
                    end
                end
                BGP:  BGP_reg_n =       data_in;
                OBP0: OBP0_reg_n =      data_in;
                OBP1: OBP1_reg_n =      data_in;
                WX:   WX_reg_n =        data_in;
                WY:   WY_reg_n =        data_in;
                KEY0: begin
                    if ( !KEY0_locked )
                        KEY0_reg_n =    data_in;
                    else
                        KEY0_reg_n =    KEY0_reg;
                end
                VBK:  VBK_reg_n[0] =    data_in[0];
                BANK: KEY0_locked_n =   1;
                BGPI: BGPI_reg_n =      data_in;
                BGPD: begin
                    BGP_RGB_we = 1;
                    if ( cpu_en && BGP_AUTO_INC )
                        BGPI_reg_n[5:0] = BGPI_reg[5:0] + 1;
                end
                OBPI: OBPI_reg_n =      data_in;
                OBPD: begin
                    OBP_RGB_we = 1;
                    if ( cpu_en && OBP_AUTO_INC )
                        OBPI_reg_n[5:0] = OBPI_reg[5:0] + 1;
                end
                OPRI: OPRI_reg_n =      data_in;
                default:; //
            endcase
            if ( addr_in_is_oam ) begin
                oam_we = 1;
            end
            if ( addr_in_is_vram ) begin
                if ( DMG_mode )
                    vram0_we = 1;
                else if ( VBK_reg[0] == 0 )
                    vram0_we = 1;
                else
                    vram1_we = 1;
            end
        end

        

        // if output_x == WX_reg, then the NEXT pixel is part of the window
        // for example, output_x == 8 corresponds to pixel 0, output_x triggers one cycle before
        // win_trigger = (output_x == WX_reg + (SCX_reg % 8)) && ((LY_reg == WY_reg) || win_y_cond) && WIN_EN;
        win_trigger = (output_x == WX_reg) && ((LY_reg == WY_reg) || win_y_cond) && WIN_EN;
        obj_height = (OBJ_SIZE == 0) ? 8 : 16;
        for ( i = 0; i < 10; i = i + 1 )
            // if ( obj_arr[i][1] + (SCX_reg % 8) == output_x )
            if ( obj_arr[i][1] == output_x )
                obj_x_hit[i] = 1;
            else
                obj_x_hit[i] = 0;
        obj_trigger = obj_priority_valid;
        
        data_base = (TILE_SEL == 0) ? 13'h1000 : 13'h0000;
        tile_base = (TILE_SEL == 0) ?   $signed(data_base) + (13'($signed(tile_idx)) * 16) : 
                                        data_base + (13'(tile_idx) * 16);
        if ( bgr_state ) begin
            map_base = (BG_MAP == 0) ? 13'h1800 : 13'h1C00;
            pix_x = (fetch_counter*8) + (SCX_reg);
            pix_y = LY_reg + SCY_reg;
        end
        else begin
        // if ( win_state ) begin
            map_base = (WIN_MAP == 0) ? 13'h1800 : 13'h1C00;
            pix_x = win_x;
            pix_y = win_y;
        end

        tile_x = pix_x / 8;
        tile_y = pix_y / 8;

        if ( !DMG_mode && (tile_attr[6] == 1) ) begin
            row_offset = (7 - (pix_y % 8)) * 2;
        end
        else begin
            row_offset = (pix_y % 8) * 2;
        end

        case ( current_mode )
            oamScan: begin
                if ( INTR_M2_EN )
                    stat_intr = 1;
                // Lock oam
                oam_we = 0;
                oam_addr = oam_idx;
                obj_is_on_line = (LY_reg + 16 >= oam_dout) && (LY_reg + 16 < oam_dout + obj_height);

                case ( oamScan_substate ) 
                    get_y_position: begin
                        if ( obj_is_on_line ) begin
                            oamScan_substate_n = get_x_position;
                            oam_idx_n = oam_idx + 1;
                            write_obj_arr = 1;
                            obj_arr_elem = 0;
                            obj_arr_data = (LY_reg + 16) - oam_dout;
                            obj_valid_n[objs_on_scanline] = 1;
                        end
                        else 
                        if ( oam_idx < 156 ) begin // if this is not last entry in OAM
                            oam_idx_n = oam_idx + 4;
                            oamScan_substate_n = get_y_position; // remain on this state
                        end
                        else
                            oamScan_substate_n = await_mode_3;
                    end
                    get_x_position: begin
                        write_obj_arr = 1;
                        obj_arr_elem = 1;
                        obj_arr_data = oam_dout;
                        oamScan_substate_n = get_obj_tile;
                        oam_idx_n = oam_idx + 1;
                    end
                    get_obj_tile: begin
                        write_obj_arr = 1;
                        obj_arr_elem = 2;
                        // If double height object, ignore LSB
                        obj_arr_data = (OBJ_SIZE == 0) ? oam_dout : oam_dout & 8'hFE;
                        oamScan_substate_n = get_obj_attr;
                        oam_idx_n = oam_idx + 1;
                    end
                    get_obj_attr: begin
                        oamScan_substate_n = ( oam_idx < 156 && objs_on_scanline < 9 ) ? // objs_on_scanline == 9, means this is 10th obj
                            get_y_position : await_mode_3;
                        write_obj_arr = 1;
                        objs_on_scanline_n = objs_on_scanline + 1;
                        obj_arr_elem = 3;
                        obj_arr_data = oam_dout;
                        oam_idx_n = oam_idx + 1;
                    end
                    await_mode_3: begin
                        if ( dot_counter == 79 ) begin // 80th dot
                            next_mode = drawing;

                            fetch_counter_n = 0;

                            win_x_n = 0;
                            output_x_n = 0;
                            discard_x_n = SCX_reg[2:0];

                            fetcher_state_n = fetcher_bgr_map_addr;
                            bgr_fifo_flush_n = 1;
                            obj_fifo_flush_n = 1;
                        end
                    end
                    default:; // all cases of one-hot state machine captured
                endcase
            end
            drawing: begin // Mode 3
                // Lock oam and vram
                oam_we = 0;
                vram0_we = 0;
                vram1_we = 0;
                vram_addr = tile_addr;

                // output stage
                // Increment output_x during initial fetch
                if ( !obj_trigger && !obj_state && output_x < 8 ) begin
                    output_x_n = output_x + 1;
                    obj_fifo_read = 1;
                end
                else
                if ( !obj_trigger && !obj_state && discard_x > 0 ) begin
                    bgr_fifo_read = (win_state) ? 0 : 1;
                    // obj_fifo_read = 1; 
                    discard_x_n = discard_x - 1;
                end
                else
                if ( !(obj_trigger || obj_state || bgr_fifo_flush || bgr_fifo_len == 0) ) begin 
                    // any of these conditions stalls the output
                    // obj_with_priority may get set to 4'hF while data is yet to be pushed to obj_fifo
                    // if ( win_state )
                    //     win_x_n = win_x + 1;
                    // if ( output_x < (8 + (SCX_reg & 8'h7)) || output_x >= (168 + (SCX_reg & 8'h7)) ) begin
                    //     de2_n = 0;
                    // end
                    // else begin
                    //     de2_n = 1;
                    // end
                    de2_n = output_x < 168 ? 1 : 0;
                    output_x_n = output_x + 1;
                    bgr_fifo_read = 1;
                    
                    // Stage 0
                    if ( DMG_mode ) begin
                        if ( obj_fifo_len > 0 ) begin
                            obj_fifo_read = 1;
                            if ( (BG_EN == 1) ) begin
                                if ( obj_pix_idx == 0 || (obj_pix_pri == 1 && bgr_pix_idx != 2'b0) )
                                    mixed_pixel0_n = {BGP_reg[2*bgr_pix_idx +:2], 3'b000, 1'b0}; // bgr_pix_pal == 3'd0 means non-blank pixel
                                else
                                    if ( obj_pix_pal == 0 )
                                        mixed_pixel0_n = {OBP0_reg[2*obj_pix_idx +:2], obj_pix_pal, 1'b1};
                                    else
                                        mixed_pixel0_n = {OBP1_reg[2*obj_pix_idx +:2], obj_pix_pal, 1'b1};
                            end
                            else begin
                                if ( obj_pix_idx == 0 )
                                    mixed_pixel0_n = {2'b00, 3'b001, 1'b0}; // blank pixel symbolized by bgr_pix_pal 3'd1 color 0
                                else
                                    if ( obj_pix_pal == 0 )
                                        mixed_pixel0_n = {OBP0_reg[2*obj_pix_idx +:2], obj_pix_pal, 1'b1};
                                    else
                                        mixed_pixel0_n = {OBP1_reg[2*obj_pix_idx +:2], obj_pix_pal, 1'b1};
                            end
                        end
                        else begin
                            if ( BG_EN == 1 )
                            // if ( (BG_EN == 1 && bgr_state == 1) || (WIN_EN == 1 && win_state == 1) )
                                mixed_pixel0_n = {BGP_reg[2*bgr_pix_idx +:2], 3'b000, 1'b0};
                            else
                                mixed_pixel0_n = {2'b00, 3'b001, 1'b0};
                        end
                    end
                    else 
                    begin // CGB_mode
                        if ( obj_fifo_len > 0 ) begin
                            obj_fifo_read = 1;
                            if ( BG_EN == 1 ) begin
                                if ( obj_pix_idx == 0 || (((obj_pix_pri | bgr_pix_pri) == 1) && (bgr_pix_idx != 0)) )
                                    mixed_pixel0_n = {bgr_pix_idx, bgr_pix_pal, 1'b0};
                                else
                                    mixed_pixel0_n = {obj_pix_idx, obj_pix_pal, 1'b1};
                            end
                            else begin
                                if ( obj_pix_idx == 0 )
                                    mixed_pixel0_n = {bgr_pix_idx, bgr_pix_pal, 1'b0};
                                else
                                    mixed_pixel0_n = {obj_pix_idx, obj_pix_pal, 1'b1};
                            end
                        end else begin
                            mixed_pixel0_n = {bgr_pix_idx, bgr_pix_pal, 1'b0};
                        end
                    end
                end
                // Stage 1
                mixed_pixel_n = mixed_pixel0;
                if ( mixed_pixel0[0] == 0 )
                    rgb_low0_n = BGP_RGB[{mixed_pixel0[3:1], mixed_pixel0[5:4], 1'b0}];
                else
                    rgb_low0_n = OBP_RGB[{mixed_pixel0[3:1], mixed_pixel0[5:4], 1'b0}];
                // Stage 2
                rgb_low_n = rgb_low0;
                if ( mixed_pixel[0] == 0 )
                    rgb_high_n = BGP_RGB[{mixed_pixel[3:1], mixed_pixel[5:4], 1'b1}];
                else
                    rgb_high_n = OBP_RGB[{mixed_pixel[3:1], mixed_pixel[5:4], 1'b1}];
                // end
                // Stage 3
                r_n = rgb_low[4:0];
                g_n = {rgb_high[1:0], rgb_low[7:5]};
                b_n = rgb_high[6:2];
                // if ( output_x >= (168 + (SCX_reg & 8'h7)) && !(de0 | de1 | de2) ) begin
                if ( output_x >= 168 && !(de0 | de1 | de2) ) begin
                    // Wait for output pipeline to empty
                    next_mode = h_blank;
                end

                // fetcher
                case ( fetcher_state )
                    fetcher_bgr_map_addr,
                    fetcher_win_map_addr: begin 
                        tile_addr_n = map_base + (tile_y * 32) + 13'(tile_x);
                        fetcher_state_n = (bgr_state) ? fetcher_bgr_read_map : fetcher_win_read_map;
                    end
                    fetcher_bgr_read_map,
                    fetcher_win_read_map: begin
                        tile_idx_n = vram0_dout;
                        if ( !DMG_mode ) 
                            tile_attr_n = vram1_dout;
                        else
                            tile_attr_n = 8'b0;
                        fetcher_state_n = (bgr_state) ? fetcher_bgr_data_addr : fetcher_win_data_addr;
                    end
                    fetcher_bgr_data_addr,
                    fetcher_win_data_addr: begin
                        tile_addr_n = tile_base + 13'(row_offset);
                        fetcher_state_n = (bgr_state) ? fetcher_bgr_low_data : fetcher_win_low_data;
                    end
                    fetcher_bgr_low_data,
                    fetcher_win_low_data: begin
                        data_low_n = (tile_attr[3] == 0) ? vram0_dout : vram1_dout;
                        tile_addr_n = tile_addr + 1;
                        fetcher_state_n = (bgr_state) ? fetcher_bgr_high_data : fetcher_win_high_data;
                    end
                    fetcher_bgr_high_data,
                    fetcher_win_high_data: begin
                        data_high_n = (tile_attr[3] == 0) ? vram0_dout : vram1_dout;
                        fetcher_state_n = (bgr_state) ? fetcher_bgr_push_fifo : fetcher_win_push_fifo;
                    end
                    fetcher_bgr_push_fifo,
                    fetcher_win_push_fifo: begin
                        if ( bgr_fifo_len == 0 || ((bgr_fifo_len == 4'd1) && (bgr_fifo_read == 1)) ) begin
                            // FIFO can be pushed to if it is empty or if its  last element is being read
                            bgr_fifo_push = 1;
                            
                            fetcher_state_n = (bgr_state) ? fetcher_bgr_map_addr : fetcher_win_map_addr;
                            if ( bgr_state )
                                fetch_counter_n = fetch_counter + 1;
                            else if ( win_state )
                                win_x_n = win_x + 8;
                            // fetch_counter_n = fetch_counter + 1;
                        end
                        if ( obj_trigger ) begin // there is valid object to be fetched
                            if ( OBJ_EN == 1 ) begin
                                current_obj_n = obj_with_priority;
                                // return to next state after obj is pushed
                                fetcher_return_n = fetcher_state_n;
                                fetcher_state_n = fetcher_obj_data_addr;
                            end
                            else// discard obj if obj rendering disabled
                                obj_valid_n[obj_with_priority] = 0;
                        end
                    end
                    fetcher_obj_wait: begin
                        fetcher_state_n = fetcher_obj_data_addr;
                    end
                    fetcher_obj_data_addr: begin
                        tile_addr_n = (obj_attr[6] == 0) ? 
                            13'(obj_tile * 16) + (13'(obj_y) * 2) :
                            13'(obj_tile * 16) + ((13'(obj_height) - 1 - 13'(obj_y)) * 2);
                        fetcher_state_n = fetcher_obj_low_data;
                    end
                    fetcher_obj_low_data: begin
                        obj_low_n = (obj_attr[3] == 0) ? vram0_dout : vram1_dout;
                        tile_addr_n = tile_addr + 1;
                        fetcher_state_n = fetcher_obj_high_data;
                    end
                    fetcher_obj_high_data: begin
                        obj_high_n = (obj_attr[3] == 0) ? vram0_dout : vram1_dout;
                        fetcher_state_n = fetcher_obj_merge_fifo;
                    end
                    fetcher_obj_merge_fifo: begin
                        obj_valid_n[current_obj] = 0;
                        for ( i = 0; i < 8; i = i + 1 ) begin
                            if ( obj_attr[5] == 1 ) begin // x-flip, push in reverse order
                                if ( i+1 > obj_fifo_len )
                                    obj_fifo_merge_n[i] = 1; // empty fifo slot
                                else if ( !OBJ_PRI_MODE ) begin
                                    if ( obj_fifo[i][5:4] != 2'b0 && {obj_high[i], obj_low[i]} != 2'b0) begin
                                        obj_fifo_merge_n[i] = (obj_addr[5:0] < obj_fifo[i][11:6]) ? 1 : 0;
                                    end
                                    else begin
                                        obj_fifo_merge_n[i] = (obj_fifo[i][5:4] == 2'b0) ? 1 : 0;
                                    end
                                end
                                else begin
                                    obj_fifo_merge_n[i] = (obj_fifo[i][5:4] == 2'b0) ? 
                                        1 : 0;
                                end
                            end
                            else begin
                                if ( i+1 > obj_fifo_len )
                                    obj_fifo_merge_n[i] = 1; // empty fifo slot
                                else if ( !OBJ_PRI_MODE ) begin
                                    if ( obj_fifo[i][5:4] != 2'b0 && {obj_high[7-i], obj_low[7-i]} != 2'b0) begin
                                        obj_fifo_merge_n[i] = (obj_addr[5:0] < obj_fifo[i][11:6]) ? 1 : 0;
                                    end
                                    else begin
                                        obj_fifo_merge_n[i] = (obj_fifo[i][5:4] == 2'b0) ? 1 : 0;
                                    end
                                end
                                else begin
                                    obj_fifo_merge_n[i] = (obj_fifo[i][5:4] == 2'b0) ? 
                                        1 : 0;
                                end
                            end
                        end
                        fetcher_state_n = fetcher_obj_push_fifo;
                    end
                    fetcher_obj_push_fifo: begin
                        obj_fifo_push = 1;
                        if ( obj_trigger ) begin
                            current_obj_n = obj_with_priority;
                            fetcher_state_n = fetcher_obj_wait;
                        end
                        else
                            fetcher_state_n = fetcher_return;
                    end
                default:; // One hot coded
                endcase
                if ( win_trigger && !win_state && !obj_trigger && !obj_state ) begin 
                    // only time fifo flush is high, state is win_map_addr, so fifo can never be flushed and pushed
                    // to in same cycle
                    // if obj_trigger || obj_state is true, the output will stop incrementing output_x
                    // in order to ensure fetcher is not stuck due to win_trigger being held high in this case,
                    // the win_trigger must let the obj state complete. On completion of one object fetch cycle,
                    // output_x will remain on the same value for at least one cycle (output needs to read the fifo
                    // in order to increment), !obj_trigger && !obj_state if all of the object have been fetched, or if
                    // the next object is not on this x. At this point, win_trigger_will finally allow the bgr fifo
                    // to be flushed on the next cycle.
                    // in other words, the condition (win_trigger && !obj_trigger && !obj_state) can only be high for one cycle for any
                    // given output_x
                    bgr_fifo_flush_n = 1;
                    fetcher_state_n = fetcher_win_read_map;
                    win_x_n = 0;
                    if ( !win_y_cond ) begin
                        // first time this frame the window was triggered
                        win_y_n = 0;
                        win_y_cond_n = 1;
                    end
                    else begin
                        win_y_n = win_y + 1;
                    end
                    tile_addr_n = (WIN_MAP == 0) ? 
                        13'h1800 + (32 * ((13'(win_y_n))/8)) : 13'h1C00 + (32 * ((13'(win_y_n))/8));
                end

            end
            h_blank: begin
                hsync_n = 0;
                if ( INTR_M0_EN )
                    stat_intr = 1;
                if ( dot_counter == 455 ) begin
                    dot_counter_n = 0;
                    oam_idx_n = 0;
                    oamScan_substate_n = get_y_position;
                    obj_valid_n = 0;
                    LY_reg_n = LY_reg + 1;
                    objs_on_scanline_n = 0;
                    
                    if ( LY_reg == 143 ) begin
                        next_mode = v_blank;
                    end
                    else begin
                        next_mode = oamScan;
                    end
                end
            end
            v_blank: begin
                vsync_n = 0;
                if ( INTR_M1_EN )
                    stat_intr = 1;
                vblank_intr = 1;
                if ( dot_counter == 455 ) begin
                    dot_counter_n = 0;
                    if ( LY_reg == 153 ) begin
                        win_y_cond_n = 0;
                        next_mode = oamScan;
                        LY_reg_n = 0;
                    end
                    else begin
                        LY_reg_n = LY_reg + 1;
                    end
                end
            end
            default:; // All cases captured
        endcase
        // DMA has highest priority over mem
        if ( DMA_state ) begin
            oam_addr = DMA_counter;
            oam_we = 1;
            if ( DMA_reg >= 8'h80 && DMA_reg <= 8'h9F ) begin
                vram_addr = ((13'(DMA_reg) - 13'h0080) << 8) | 13'(DMA_counter);
                oam_din = VBK_reg[0] == 0 ? vram0_dout : vram1_dout;
            end
            else begin
                rout = 1;
                addr_out = {DMA_reg, DMA_counter};
                oam_din = dma_data_in;
            end
            if ( DMA_counter == 159 ) begin // state and counter reg only clocked on cpu_en
                DMA_state_n = 0;
                DMA_counter_n = 0;
            end else begin
                DMA_counter_n = DMA_counter + 1;
            end
        end
        if ( start_DMA ) begin
            // Technically my DMA implementation can end one cycle early but I fail some of
            // the mooneye tests when I do that
            DMA_state_n = 1;
            DMA_counter_n = 0;
        end
        
        if ( ren ) begin
            case ( addr_in )
                LCDC:   data_out = LCDC_reg;
                STAT:   data_out = STAT_reg;
                SCY:    data_out = SCY_reg;
                SCX:    data_out = SCX_reg;
                LY:     data_out = LY_reg;
                // LY:     data_out = 8'h90;
                LYC:    data_out = LYC_reg;
                DMA:    data_out = DMA_reg;
                BGP:    data_out = BGP_reg;
                OBP0:   data_out = OBP0_reg;
                OBP1:   data_out = OBP1_reg;
                WX:     data_out = WX_reg;
                WY:     data_out = WY_reg;
                KEY0:   data_out = KEY0_reg;
                VBK:    data_out = VBK_reg;
                BGPI:   data_out = BGPI_reg;
                BGPD: begin
                    if ( current_mode == drawing )
                        data_out = 8'hFF;
                    else
                        data_out = BGP_RGB[BGPI_reg[5:0]];
                end
                OBPI:   data_out = OBPI_reg;
                OBPD: begin
                    if ( current_mode == drawing )
                        data_out = 8'hFF;
                    else
                        data_out = OBP_RGB[OBPI_reg[5:0]];
                end
                OPRI:   data_out = OPRI_reg;
                default: begin
                    if ( addr_in >= 16'h8000 && addr_in <= 16'h9FFF ) // VRAM address range 
                        if ( VBK_reg[0] == 1'b0 || DMG_mode )
                            data_out = (current_mode != drawing && DMA_state != 1) ? vram0_dout : 8'hFF;
                        else // if ( VBK_reg[0] == 1'b1 )
                            data_out = (current_mode != drawing && DMA_state != 1) ? vram1_dout : 8'hFF;
                    else
                    if ( addr_in >= 16'hFE00 && addr_in <= 16'hFE9F ) // OAM address range
                        data_out = (current_mode != drawing && current_mode != oamScan && DMA_state != 1) ? 
                            OAM[oam_addr] : 8'hFF;
                    else
                        data_out = 8'h00;
                end
            endcase
        end
        else            data_out = 8'h00;

    end

    // reg hsync_prev = 1;
    // reg vsync_prev = 1;
    // reg [14:0] framebuf [0:(160*144)-1]/*verilator public*/; 
    // integer idx = 0, jdx = 0;
    // integer idxi, jdxi;
    // initial begin 
    //     for ( idxi = 0; idxi < 144; idxi = idxi + 1 ) begin
    //         for ( jdxi = 0; jdxi < 160; jdxi = jdxi + 1 ) begin
    //             framebuf[(idxi*160)+jdxi] = 0;
    //         end
    //     end
    //     idx = 0;
    //     jdx = 0;
    // end

    

    // always @ ( posedge clk ) begin
    //     if ( de ) begin
    //         framebuf[(idx*160)+jdx] <= {r, g, b};
    //         jdx <= jdx + 1;
    //         hsync_prev <= hsync;
    //         vsync_prev <= vsync;
    //     end
    //     else if ( ~hsync & hsync_prev ) begin
    //         jdx <= 0;
    //         idx <= idx + 1;
    //     end
    //     else if ( ~vsync & vsync_prev ) begin
    //         jdx <= 0;
    //         idx <= 0;
    //     end
    //     hsync_prev <= hsync;
    //     vsync_prev <= vsync;
    // end


endmodule

