`default_nettype none
module Core( 
    `ifdef DEBUG
    output wire dbg_break,
    `endif
    input wire clk, rst, en, 
    input wire [7:0] din,
    output reg [7:0] dout, 
    output reg [15:0] addrbus, 
    output reg we, re,
    input wire [4:0] intr_req,
    output wire dbl_spd,
    output reg cpu_en,
    output reg stop,
    input wire [1:0] LCD_mode
);

    reg [7:0] databus;

    reg [4:0] intr_req_reg;

    `include "RegMap.vh"
    `include "Control_params.vh"
    `include "ALU_params.vh"
    `include "IDU_params.vh"
    `include "RegFile_params.vh"

    integer i;

    reg [1:0] cpu_phase = 0, cpu_phase_n;
    reg last_dot_of_phase;
    
    wire sig_writeback, sig_data_sel, sig_readmem;
    wire sig_load_flags;
    wire [3:0] sig_clear_flags;
    wire [3:0] sig_r1, sig_r2, sig_rd, sig_addrh, sig_addrl;
    wire [4:0] sig_flag_mask;
    wire [15:0] sig_addrbus;
    wire [ALU_OPWIDTH:0] sig_alu_op;
    wire [IDU_OPWIDTH:0] sig_idu_op;
    wire [7:0] ctr_data;
    wire [2:0] sig_rd_idu;
    wire [7:0] sig_ack_IF;
    wire sig_stop, sig_halt;

    wire [7:0] reg_din;

    wire [7:0] alu_in1, alu_in2;
    wire [7:0] alu_out;
    wire [3:0] alu_flags, saved_flags;

    wire [15:0] idu_out;

    wire [1:0] cc;
    wire cc_result;

    reg [7:0] hram [0:126];
    reg [6:0] hram_addr;
    reg [7:0] hram_din;
    wire [7:0] hram_dout = hram[hram_addr];
    reg hram_we;
    reg addr_in_hram;

    reg enable_controller;

    //  |   SPEED   |     ?     |     ?     |     ?     |     ?     |     ?     |     ?     |   ARMED   |
    //  |     R     |                                                                       |    R/W    |
    // cpu speed control
    localparam [7:0] KEY1_mask = 8'h7E; 
    reg [7:0] KEY1_reg = 8'h00, KEY1_n;
    reg speed_n = 0;
    wire speed = KEY1_reg[7];
    assign dbl_spd = speed;
    wire armed = KEY1_reg[0];
    reg cpu_active;

    // Interupt registers. Bits 7-5 are unused
    //  |     7     |     6     |     5     |     4     |     3     |     2     |     1     |     0     |
    //  |     -     |     -     |     -     |  JYP_intr |  SER_intr |  TIM_intr |  LCD_intr |  VBK_intr |
    localparam [7:0] IE_mask = 8'h00, IF_mask = 8'hE0;
    reg [7:0] IE_reg = 8'h00, IF_reg = 8'h00, IE_n, IF_n;
    // wire sig_wake = |( IE[4:0] & IF[4:0]); should happen on positive edges
    reg sig_wake = 0, sig_wake_n = 0;

    //  |                                             HDMA1                                             |
    //  |                                              W/O                                              |
    reg [7:0] HDMA1_reg = 8'h00, HDMA1_n;  
    //  |                                             HDMA2                                             |
    //  |                                              W/O                                              |
    reg [7:0] HDMA2_reg = 8'h00, HDMA2_n;
    wire [15:0] HDMA_src_addr = {HDMA1_reg, HDMA2_reg};
    
    //  |                                             HDMA3                                             |
    //  |                                              W/O                                              |
    reg [7:0] HDMA3_reg = 8'h00, HDMA3_n; 
    //  |                                             HDMA4                                             |
    //  |                                              W/O                                              |
    reg [7:0] HDMA4_reg = 8'h00, HDMA4_n; 
    wire [15:0] HDMA_dst_addr = {HDMA3_reg, HDMA4_reg};

    //  |                                             HDMA5                                             |
    //  |                                              R/W                                              |
    reg [7:0] HDMA5_reg = 8'h7F, HDMA5_n; 
    wire [6:0] HDMA_remaining_transfers = HDMA5_reg[6:0];
    wire HDMA_active = HDMA5_reg[7];
    localparam HDMA_general = 1'b0;
    localparam HDMA_hblank = 1'b1;
    reg HDMA_mode = HDMA_general, HDMA_mode_n;

    localparam [2:0] HDMA_WAIT = 3'b001;
    localparam [2:0] HDMA_RECV = 3'b010;
    localparam [2:0] HDMA_SEND = 3'b100;
    reg [2:0] HDMA_state = HDMA_WAIT, HDMA_state_n;

    reg [3:0] HDMA_count = 0, HDMA_count_n;
    reg [7:0] HDMA_byte = 0, HDMA_byte_n;

    assign reg_din = sig_data_sel == DIN ? databus : alu_out;

    ControlUnit controller (
        `ifdef DEBUG
        .dbg_break(dbg_break),
        `endif
        .clk( clk ), .en( cpu_en & enable_controller ), .rst( rst ),
        .IE( IE_reg ), .IF ( IF_reg ), .KEY1( KEY1_reg ),
        .ack_IF( sig_ack_IF ),
        .data( databus ),
        .data_sel( sig_data_sel ),
        .ctr( ctr_data ),
        .r1( sig_r1 ), .r2( sig_r2 ), .rd( sig_rd ), .rd_idu( sig_rd_idu ),
        .addrh( sig_addrh ), .addrl( sig_addrl ),
        .read( sig_readmem ),
        .write( sig_writeback ),
        .alu_op( sig_alu_op ), 
        .flag_mask( sig_flag_mask ), .load_flags( sig_load_flags ), .clear_flags( sig_clear_flags ),
        .idu_op( sig_idu_op ),
        .cc( cc ), .cc_true( cc_result ),
        .wake( sig_wake ),
        .stop( sig_stop ), .halt( sig_halt )
    );

    RegisterFile regfile (
        .clk( clk ), .en( cpu_en ), .rst( rst ),
        .r1( sig_r1 ), .r2( sig_r2 ), .rd( sig_rd ), .rd_idu( sig_rd_idu ),
        .addrh( sig_addrh ), .addrl( sig_addrl ), .addr( sig_addrbus ),
        .alu1( alu_in1 ), .alu2( alu_in2 ),
        .din( reg_din ), 
        .flags_in( alu_flags ), .flags_out( saved_flags ), .mask(sig_flag_mask), .clear_flags( sig_clear_flags ),
        .ctr( ctr_data ),
        .idu( idu_out ),
        .load_flags( sig_load_flags )
    );
    
    ALU alu_inst (
        .op( sig_alu_op ),
        .in1( alu_in1 ), .in2( alu_in2 ), .flags_in( saved_flags ),
        .out( alu_out ), .flags_out( alu_flags )
    );
 
    IDU idu_inst (
        .addr_in( sig_addrbus ),
        .op( sig_idu_op ),
        .carry( alu_flags[0] ), .sign( alu_in2[7] ),
        .out( idu_out )
    );

    CondCheck cond_check (
        .cc( cc ),
        .flags( saved_flags ),
        .result( cc_result )
    );

    initial begin
        for ( i = 0; i < 127; i = i + 1 )
            hram[i] = 0;
    end
    
    always @ ( posedge clk ) begin
        if ( rst ) begin
            IE_reg <= 8'h00;
            IF_reg <= 8'h00;
            KEY1_reg <= 8'h00;
            HDMA1_reg <= 8'h00;
            HDMA2_reg <= 8'h00;
            HDMA3_reg <= 8'h00;
            HDMA4_reg <= 8'h00;
            HDMA5_reg <= 8'h7F;
            HDMA_mode <= HDMA_general;
            HDMA_state <= HDMA_WAIT;
            HDMA_count <= 0;
            HDMA_byte <= 0;
            cpu_phase <= 0;
            intr_req_reg <= intr_req;
        end
        else begin
            sig_wake <= sig_wake_n; 
            if ( en ) begin
                cpu_phase <= cpu_phase_n;
                IF_reg <= IF_n;
                IE_reg <= IE_n;
                KEY1_reg <= KEY1_n;
                HDMA1_reg <= HDMA1_n;
                HDMA2_reg <= HDMA2_n;
                HDMA3_reg <= HDMA3_n;
                HDMA4_reg <= HDMA4_n;
                HDMA5_reg <= HDMA5_n;
                HDMA_mode <= HDMA_mode_n;
                HDMA_state <= HDMA_state_n;
                HDMA_count <= HDMA_count_n;
                HDMA_byte <= HDMA_byte_n;
                intr_req_reg <= intr_req;
                if ( hram_we )
                    hram[hram_addr] <= hram_din;
                // KEY1_reg[7] <= speed_n;
                // intr_req_reg <= intr_req;
                // for ( i = 0; i < 5; i = i + 1 ) begin
                //     if ( sig_ack_IF[i] )
                //         IF_reg[i] <= 0;
                //     if ( intr_req[i] & ~intr_req_reg[i] ) // intr posedge
                //         IF_reg[i] <= 1;
                // end
                // if ( sig_writeback ) begin
                //     case ( addrbus )
                //     IF:     IF_reg <= databus & (~IF_mask);
                //     IE:     IE_reg <= databus & (~IE_mask);
                //     KEY1:   KEY1_reg[0] <= databus[0];
                //     default: begin 
                //         if ( addrbus >= 16'hFF80 && addrbus <= 16'hFFFE ) begin
                //             hram[addrbus - 16'hFF80] <= databus;
                //         end
                //     end
                //     endcase
                // end
            end 
        end
    end

    always @* begin
        IE_n = IE_reg;
        IF_n = IF_reg;
        KEY1_n = KEY1_reg;
        HDMA1_n = HDMA1_reg;
        HDMA2_n = HDMA2_reg;
        HDMA3_n = HDMA3_reg;
        HDMA4_n = HDMA4_reg;
        HDMA5_n = HDMA5_reg;
        HDMA_mode_n = HDMA_mode;
        HDMA_state_n = HDMA_state;
        HDMA_count_n = HDMA_count;
        HDMA_byte_n = HDMA_byte;
        addrbus = 16'b0;
        cpu_active = 1;
        enable_controller = 1;
        
        speed_n = speed;
        // sig_wake_n = sig_wake;
        stop = 0;
        we = 0;
        re = 0;
        dout = 0;
        databus = alu_out;
        last_dot_of_phase = (speed == 0 && cpu_phase == 'd3) || (speed == 1 && cpu_phase == 'd1);
        hram_addr = sig_addrbus - 16'hFF80;
        hram_din = 8'b0;
        hram_we = 0;
        addr_in_hram = sig_addrbus >= 16'hFF80 && sig_addrbus <= 16'hFFFE;

        for ( i = 0; i < 5; i = i + 1 ) begin
            if ( sig_ack_IF[i] )
                IF_n[i] = 0;
            else if ( intr_req[i] & ~intr_req_reg[i] ) begin // intr posedge
                IF_n[i] = 1;
            end
        end
 
        if ( sig_stop == 1 )
            if ( armed == 1 )
                KEY1_n[7] = ~speed;
            else
                stop = 1;

        if ( stop ) begin
            cpu_en = en && (cpu_phase == 'd0) && (sig_wake == 1);
        end 
        else if ( sig_halt ) begin
            cpu_en = en && (cpu_phase == 'd0); // outside modules still get enable signal
            if ( sig_wake )
                enable_controller = 1;
            else
                enable_controller = 0;
        end
        else if ( HDMA_active ) begin
            cpu_en = 0;
            cpu_active = 0;
            case ( HDMA_state )
                HDMA_WAIT: begin // wait until end of hblank
                    cpu_active = 1;
                    // This state should not be entered for general purpose dma
                    cpu_en = en && (cpu_phase == 'd0); // while HDMA is waiting CPU resumes operation
                    if ( LCD_mode != 2'b00 ) begin
                        HDMA_state_n = HDMA_RECV;
                    end
                end
                HDMA_RECV: begin // doubles as wait state for hblank DMA
                    if ( HDMA_mode == HDMA_general || LCD_mode == 2'b00 ) begin
                        re = 1;
                        addrbus = {HDMA_src_addr[15:4], 4'b0} + 16'(HDMA_count);
                        HDMA_byte_n = din;
                        HDMA_state_n = HDMA_SEND;
                    end else begin
                        // HDMA_mode == HDMA_hblank && LCD_mode != 2'b00
                        cpu_en = en && (cpu_phase == 'd0);
                        cpu_active = 1;
                    end
                end
                HDMA_SEND: begin
                    addrbus = {3'b100, HDMA_dst_addr[12:4], 4'b0} + 16'(HDMA_count);
                    dout = HDMA_byte;
                    we = 1;
                    HDMA_count_n = HDMA_count + 1;
                    HDMA_state_n = HDMA_RECV;
                    if ( HDMA_count == 4'hF ) begin // end of block
                        HDMA5_n[6:0] = HDMA5_reg[6:0] - 1;
                        {HDMA1_n, HDMA2_n} = HDMA_src_addr + 16;
                        {HDMA3_n, HDMA4_n} = HDMA_dst_addr + 16; 
                        if ( HDMA_remaining_transfers == 0 ) begin // transfer done
                            HDMA5_n[7] = 1'b0;
                        end 
                        if ( HDMA_mode == HDMA_hblank ) begin
                            HDMA_state_n = HDMA_WAIT; // Stop transferring for rest of hblank
                        end
                    end
                end
                default:;//
            endcase
        end
        else begin
            // CPU not stopped or halted, and HDMA not active
            cpu_active = 1;
            cpu_en = en && (cpu_phase == 'd0);
        end

        // sig_wake_n = |(intr_req & ~IF_reg[4:0]);
        if ( cpu_phase == 0 ) begin
            sig_wake_n = |(intr_req & ~intr_req_reg);
        end else begin
            sig_wake_n = |(intr_req & ~intr_req_reg) | sig_wake;
        end
        if ( last_dot_of_phase ) begin
            cpu_phase_n = 0;
        end
        else begin
            cpu_phase_n = cpu_phase + 1;
        end

        if ( cpu_active ) begin
            if ( sig_writeback ) begin
                case ( sig_addrbus )
                    IF: IF_n = alu_out & (~IF_mask);
                    IE: IE_n = alu_out & (~IE_mask);
                    KEY1: KEY1_n = alu_out & (~KEY1_mask);
                    HDMA1: HDMA1_n = alu_out;
                    HDMA2: HDMA2_n = alu_out;
                    HDMA3: HDMA3_n = alu_out;
                    HDMA4: HDMA4_n = alu_out;
                    HDMA5: begin
                        if ( cpu_en ) begin
                            if ( !HDMA_active ) begin
                                HDMA5_n = alu_out | 8'h80; // activate HDMA
                                HDMA_mode_n = alu_out[7];
                                HDMA_state_n = HDMA_RECV;
                                HDMA_count_n = 0;
                            end
                            else begin
                                HDMA5_n = HDMA5_reg & 8'h7F; // deactivate HDMA
                            end
                        end
                    end
                    default: begin
                        if ( addr_in_hram ) begin
                            hram_din = alu_out;
                            hram_we = 1;
                        end
                        else begin
                            we = 1;    
                            addrbus = sig_addrbus;     
                            dout = alu_out;
                        end
                    end
                endcase
            end

            // cpu_en = en && (cpu_phase == 'd0) && (stop == 0 || sig_wake == 1);

            

            // if ( sig_writeback ) begin
            //     dout = alu_out;
            //     case ( addrbus )
            //     IF, IE, KEY1: we = 0; // CPU will handle these writes
            //     default: we = addr_in_hram ? 0 : 1; 
            //     endcase
            // end
            // else 
            if ( sig_readmem ) begin
                // re = 0;
                case ( sig_addrbus )
                    // IF:     databus = IF_reg | IF_mask;
                    IF:     databus = IF_reg & (~IF_mask);
                    IE:     databus = IE_reg | IE_mask;
                    KEY1:   databus = KEY1_reg | KEY1_mask;
                    HDMA1, 
                    HDMA2,
                    HDMA3, 
                    HDMA4:  databus = 8'hFF;
                    // HDMA5[7] read 1 when not active, but internally 
                    // is represetend as 0 when not active
                    HDMA5:  databus = HDMA5_reg ^ 8'h80;
                    default: begin
                        if ( addr_in_hram ) begin
                            databus = hram_dout;
                            // databus = hram[addrbus - 16'hFF80];
                        end else begin
                            re = 1;
                            addrbus = sig_addrbus;
                            databus = din;
                        end
                    end
                endcase
            end
        end
    end

    // always @* begin
    //     re = 0;
    //     if ( sig_readmem && (addrbus < 16'hFF80 || addrbus > 16'hFFFE) )
    //         re = 1; 
    // end

    `ifdef DEBUG
    always @ ( posedge clk ) begin
        if ( controller.fetch ) begin
            // $display("addr: %x", addrbus);
            // $display("IR: %b", controller.IR);
        end
    end
    `endif

endmodule