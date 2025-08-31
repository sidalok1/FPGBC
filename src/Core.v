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

    wire [7:0] reg_din;

    wire [7:0] alu_in1, alu_in2;
    wire [7:0] alu_out;
    wire [3:0] alu_flags, saved_flags;

    wire [15:0] idu_out;

    wire [1:0] cc;
    wire cc_result;

    assign write_mem = sig_writeback;

    assign reg_din = sig_data_sel == DIN ? din : alu_out;

    assign dout = alu_out;

    reg [7:0] IR = 0;
    wire fetch;

    ControlUnit controller (
        .clk( clk ), .wake( wake ),
        .IR( IR ), .fetch( fetch ),
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
        if ( fetch ) begin 
            IR <= din;
        end
    end

endmodule