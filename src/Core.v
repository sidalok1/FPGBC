`default_nettype none
module Core( 
    input wire clk, rst, en, 
    input wire [7:0] din,
    output reg [7:0] dout, 
    output wire [15:0] addrbus, 
    output reg we, re,
    input wire [4:0] intr_req,
    output wire dbl_spd,
    output reg cpu_en,
    output reg stop
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
    reg addr_in_hram;

    //  |   SPEED   |     ?     |     ?     |     ?     |     ?     |     ?     |     ?     |   ARMED   |
    //  |     R     |                                                                       |    R/W    |
    // cpu speed control
    reg [7:0] KEY1_reg = 8'h0; // reads return {7'b1, [VRAM BANK NUMBER]}
    reg speed_n = 0;
    wire speed = KEY1_reg[7];
    assign dbl_spd = speed;
    wire armed = KEY1_reg[0];

    // Interupt registers. Bits 7-5 are unused
    //  |     7     |     6     |     5     |     4     |     3     |     2     |     1     |     0     |
    //  |     -     |     -     |     -     |  JYP_intr |  SER_intr |  TIM_intr |  LCD_intr |  VBK_intr |
    reg [7:0] IE_reg = 0, IF_reg = 0;
    // wire sig_wake = |( IE[4:0] & IF[4:0]); should happen on positive edges
    reg sig_wake = 0, sig_wake_n = 0;

    assign reg_din = sig_data_sel == DIN ? databus : alu_out;

    ControlUnit controller (
        .clk( clk ), .en( cpu_en ), .rst( rst ),
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
        .addrh( sig_addrh ), .addrl( sig_addrl ), .addr( addrbus ),
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
        .addr_in( addrbus ),
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
            IF_reg <= 0;
            KEY1_reg <= 0;
            cpu_phase <= 0;
            intr_req_reg <= 0;
        end
        else begin
            sig_wake <= sig_wake_n; 
            if ( en ) begin
                cpu_phase <= cpu_phase_n;
                KEY1_reg[7] <= speed_n;
                intr_req_reg <= intr_req;
                for ( i = 0; i < 5; i = i + 1 ) begin
                    if ( sig_ack_IF[i] )
                        IF_reg[i] <= 0;
                    if ( intr_req[i] & ~intr_req_reg[i] ) // intr posedge
                        IF_reg[i] <= 1;
                end
                if ( sig_writeback ) begin
                    case ( addrbus )
                    IF:     IF_reg <= databus;
                    IE:     IE_reg <= databus;
                    KEY1:   KEY1_reg[6:0] <= databus[6:0];
                    default: begin
                        if ( addrbus >= 16'hFF80 && addrbus <= 16'hFFFE ) begin
                            hram[addrbus - 16'hFF80] <= databus;
                        end
                    end
                    endcase
                end
            end 
        end
    end

    always @* begin
        speed_n = speed;
        sig_wake_n = 0;
        stop = 0;
        we = 0;
        // re = 0;
        dout = 0;
        databus = alu_out;
        last_dot_of_phase = (speed == 0 && cpu_phase == 'd3) || (speed == 1 && cpu_phase == 'd1);
        addr_in_hram = addrbus >= 16'hFF80 && addrbus <= 16'hFFFE;

        // if ( sig_stop == 1 )
        //     if ( armed == 1 )
        //         speed_n = ~speed;
        //     else
        //         stop = 1;

        // cpu_en = en && (cpu_phase == 'd0) && !(stop || sig_halt);
        cpu_en = en && (cpu_phase == 'd0);

        sig_wake_n = |(intr_req & ~IF_reg[4:0]);
        if ( last_dot_of_phase )
            cpu_phase_n = 0;
        else
            cpu_phase_n = cpu_phase + 1;

        if ( sig_writeback ) begin
            dout = alu_out;
            case ( addrbus )
            IF, IE, KEY1: we = 0; // CPU will handle these writes
            default: we = addr_in_hram ? 0 : 1; 
            endcase
        end
        else if ( sig_readmem ) begin
            // re = 0;
            case ( addrbus )
                IF:     databus = IF_reg;
                IE:     databus = IE_reg;
                KEY1:   databus = KEY1_reg;
                default: begin
                    if ( addr_in_hram ) begin
                        databus = hram[addrbus - 16'hFF80];
                    end else begin
                        databus = din;
                    end
                    // re = 1;
                end
            endcase
        end
    end

    always @* begin
        re = 0;
        if ( sig_readmem && (addrbus < 16'hFF80 || addrbus > 16'hFFFE) )
            re = 1; 
    end

    `ifdef DEBUG
    always @ ( posedge clk ) begin
        if ( controller.fetch ) begin
            // $display("addr: %x", addrbus);
            // $display("IR: %b", controller.IR);
        end
    end
    `endif

endmodule