module Core( clk, din, dout, addrbus, write_mem, wake );

    `include "Control_params.vh"
    `include "ALU_params.vh"
    `include "IDU_params.vh"
    `include "RegFile_params.vh"

    input clk;
    input wake;
    input wire [7:0] din;
    output wire [7:0] dout;
    output wire [15:0] addrbus;
    output wire write_mem;
    
    wire sig_writeback, sig_data_sel;
    wire [3:0] sig_r1, sig_r2, sig_rd, sig_addrh, sig_addrl;
    wire [4:0] sig_flag_mask;
    wire [ALU_OPWIDTH:0] sig_alu_op;
    wire [IDU_OPWIDTH:0] sig_idu_op;
    wire [7:0] ctr_data;
    wire [2:0] sig_rd_idu;
    wire [7:0] sig_rst_IF;

    wire [7:0] reg_din;

    wire [7:0] alu_in1, alu_in2;
    wire [7:0] alu_out;
    wire [3:0] alu_flags, saved_flags;

    wire [15:0] idu_out;

    wire [1:0] cc;
    wire cc_result;

    // Interupt registers. Bits 7-5 are unused
    //  | 7 6 5 |   4   |   3   |   2   |   1   |   0   |
    //  | 1 1 1 | Joypad| Serial| Timer |  LCD  | VBlank|
    reg [7:0] IE = 0, IF = 0;
    // Joypad register. Write 0 to bit 5 or 4 for buttons or d-pad respectively
    // Reads from bit 3 to 0 are active low. Will read FFh if both bit 5 and 4 
    //are high
    //  |  7  6  |   5   |   4   |   3   |   2   |   1   |   0   |
    //  |  1  1  |   0   |   1   |/Start |/Select|  /B   |  /A   |
    //  |  1  1  |   1   |   0   | /Down |  /Up  | /Left | /Right|
    //  |  1  1  |   1   |   1   |   1   |   1   |   1   |   1   |
    // Setting both bits 5 and 4 to zero is a logical and of input signals
    reg [7:0] P1 = 8'hFF;

    assign write_mem = sig_writeback;

    assign reg_din = sig_data_sel == DIN ? din : alu_out;

    assign dout = alu_out;


    ControlUnit controller (
        .clk( clk ),
        .IE( IE ), .IF ( IF ),
        .ack_IF( sig_rst_IF ),
        .data( din ),
        .data_sel( sig_data_sel ),
        .ctr( ctr_data ),
        .r1( sig_r1 ), .r2( sig_r2 ), .rd( sig_rd ), .rd_idu( sig_rd_idu ),
        .addrh( sig_addrh ), .addrl( sig_addrl ),
        .writeback( sig_writeback ),
        .alu_op( sig_alu_op ), .flag_mask( sig_flag_mask ),
        .idu_op( sig_idu_op ),
        .cc( cc ), .cc_true( cc_result ),
        .intr_req( wake )
    );

    RegisterFile regfile (
        .clk( clk ),
        .r1( sig_r1 ), .r2( sig_r2 ), .rd( sig_rd ), .rd_idu( sig_rd_idu ),
        .addrh( sig_addrh ), .addrl( sig_addrl ), .addr( addrbus ),
        .alu1( alu_in1 ), .alu2( alu_in2 ),
        .din( reg_din ), .flags_in( alu_flags ), .flags_out( saved_flags ), .mask(sig_flag_mask),
        .ctr( ctr_data ),
        .idu( idu_out )
    );
    
    ALU alu_inst (
        .op( sig_alu_op ),
        .in1( alu_in1 ), .in2( alu_in2 ), .flags_in( saved_flags ),
        .out( alu_out ), .flags_out( alu_flags )
    );
 
    IDU idu_inst (
        .addr_in( addrbus ),
        .op( sig_idu_op ),
        .carry( alu_flags[0] ), .sign( alu_in1[7] ),
        .out( idu_out )
    );

    CondCheck cond_check (
        .cc( cc ),
        .flags( saved_flags ),
        .result( cc_result )
    );
    
    always @ ( posedge clk ) begin
        if ( sig_rst_IF ) begin
            IF <= IF & (~sig_rst_IF);
        end
    end

endmodule