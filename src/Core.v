`include "Control_headers.vh"
`include "ALU_headers.vh"
`include "IDU_headers.vh"
`include "RegFile_headers.vh"

module Core( clk, din, dout, addrbus, write_mem, wake );

    input clk;
    input wake;
    input wire [7:0] din;
    output wire [7:0] dout;
    output wire [15:0] addrbus;
    output wire write_mem;
    
    wire sig_writeback, sig_data_sel;
    wire [3:0] sig_r1, sig_r2, sig_rd, sig_addrh, sig_addrl;
    wire [4:0] sig_flag_mask;
    wire [`ALU_opwidth:0] sig_alu_op;
    wire [`IDU_opwidth:0] sig_idu_op;
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

    assign reg_din = sig_data_sel == `din ? din : alu_out;

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
        .in1( alu_in1 ), .in2( alu_in2 ), .carry_in( saved_flags[0] ),
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

    // always @* begin
        // next = 0;
        // fetch = 0;
        // addr = `addr_pc;
        // write_mem = 0;
        // writez = `wz_na;
        // writew = `wz_na;
        // reg_sel1 = `x1;
        // reg_sel2 = `x2;
        // reg_write1 = `src_none;
        // reg_write2 = `src_none;
        // r16_sel = `r16_none;
        // idu_dest = `idu_none;
        // idu_op = `inc;
        // cc = `cond_none;
        // if ( !prefix ) begin
        //     case ( block )
        //     'b00: begin
        //         case ( IR[2:0] )
        //         'b000: begin
        //             casex ( IR[5:3] )
        //             'b000: begin
        //                 //TESTED: nop
        //                 next = 0;
        //                 r16_write = PC + 1;
        //                 idu_dest = `idu_pc;
        //                 fetch = 1;
        //             end
        //             'b001: begin 
        //                 //TESTED: ld [imm16], sp
        //                 case ( state )
        //                 0: begin
        //                     next = 1;
        //                     writez = `wz_din;
        //                     idu_dest = `idu_pc;
        //                 end
        //                 1: begin
        //                     next= 2;
        //                     writew = `wz_din;
        //                     idu_dest = `idu_pc;
        //                 end
        //                 2: begin
        //                     next = 3;
        //                     addr = `addr_wz;
        //                     dout = SP[7:0];
        //                     write_mem = 1;
        //                     idu_dest = `idu_wz;
        //                 end
        //                 3: begin
        //                     next = 4;
        //                     addr = `addr_wz;
        //                     write_mem = 1;
        //                     dout = SP[15:8];
        //                 end
        //                 4: begin 
        //                     next = 0;
        //                     fetch = 1;
        //                     idu_dest = `idu_pc;
        //                 end
        //                 default: `INVALID_STATE("ld [imm16], sp")
        //                 endcase
        //             end
        //             'b010:; //TODO: stop
        //             'b011: begin
        //                 //TEST: jr imm8
        //                 case (state)
        //                 0: begin
        //                     next = 1;
        //                     writez = `wz_din;
        //                 end
        //                 1: begin
        //                     next = 2;
        //                     alu_op = `ADD;
        //                     alu_in1 = z;
        //                     alu_in2 = PC[7:0];

        //                     writez = `wz_alu;

        //                     addr = `addr_pch;
        //                     if (alu_c && !z[7])
        //                         idu_op = `inc;
        //                     else
        //                         idu_op = `dec;
        //                     idu_dest = (alu_c ^ z[7]) ? `idu_w : `idu_none;
        //                 end
        //                 2: begin
        //                     next = 0;
        //                     addr = `addr_wz;
        //                     fetch = 1;
        //                     idu_dest = `idu_pc;
        //                 end
        //                 default: `INVALID_STATE("jr imm8")
        //                 endcase
        //             end
        //             'b1xx: begin
        //                 //TEST: jr cond, imm8
        //                 case ( state ) 
        //                 0: begin
        //                     next = 1;
        //                     writez = `wz_din;
        //                     cc = IR[4:3];
        //                 end
        //                 1: begin
        //                     if (cond) begin
        //                         next = 2;
        //                         alu_op = `ADD;
        //                         alu_in1 = z;
        //                         alu_in2 = PC[7:0];

        //                         writez = `wz_alu;

        //                         addr = `addr_pch;
        //                         if (alu_c && !z[7])
        //                             idu_op = `inc;
        //                         else
        //                             idu_op = `dec;
        //                         idu_dest = (alu_c ^ z[7]) ? `idu_w : `idu_none;
        //                     end else begin
        //                         next = 0;
        //                         fetch = 1;
        //                         idu_dest = `idu_pc;
        //                     end
        //                 end
        //                 2: begin
        //                     next = 0;
        //                     addr = `addr_wz;
        //                     fetch = 1;
        //                     idu_dest = `idu_wz;
        //                 end
        //                 default: `INVALID_STATE("jr cond, imm8")
        //                 endcase
        //             end
        //             endcase
        //         end
        //         'b001: begin
        //             if ( IR[3] ) begin
        //                 //TEST: add hl, r16
        //                 case ( state )
        //                 0: begin
        //                     next = 1;
        //                     alu_op = `ADD;
        //                     alu_in1 = regs[`l];
        //                     alu_in2 = r16[IR[5:4]][7:0];

        //                     reg_write1 = `src_alu_out;
        //                     reg_sel1 = `l;

        //                     reg_write2 = `src_alu_flags;
        //                     reg_sel2 = `f;
        //                     flags_mask = `fn | `fh | `fc;
        //                 end
        //                 1: begin
        //                     next = 0;
        //                     alu_op = `ADC;
        //                     alu_in1 = regs[`h];
        //                     alu_in2 = r16[IR[5:4]][15:8];

        //                     reg_write1 = `src_alu_out;
        //                     reg_sel1 = `h;

        //                     reg_write2 = `src_alu_flags;
        //                     reg_sel2 = `f;
        //                     flags_mask = `fn | `fh | `fc;

        //                     fetch = 1;
        //                     idu_dest = `idu_pc;
        //                 end
        //                 default: `INVALID_STATE("add hl, r16")
        //                 endcase
        //             end else begin
        //                 //TEST: ld r16, imm16
        //                 case ( state )
        //                 0: begin
        //                     next = 1;
        //                     writez = `wz_din;
        //                     idu_dest = `idu_pc;
        //                 end
        //                 1: begin
        //                     next = 2;
        //                     writew = `wz_din;
        //                     idu_dest = `idu_pc;
        //                 end
        //                 2: begin
        //                     next = 0;
        //                     fetch = 1;
        //                     idu_dest = `idu_pc;
        //                     r16_write = `wz;
        //                     r16_sel = `r16_regs;
        //                 end
        //                 default: `INVALID_STATE("ld r16, imm16")
        //                 endcase
        //             end
        //         end
        //         'b010: begin
        //             if ( IR[3] ) begin
        //                 //TEST: ld a, [r16mem]
        //                 case ( state )
        //                 0: begin
        //                     next = 1;
        //                     addr = `addr_r16_mem;
        //                     writez = `wz_din;
        //                     idu_op = IR[5]; //HL-
        //                     idu_dest = IR[5] ? `idu_hl : `idu_none;// HL+ || HL-
        //                 end
        //                 1: begin
        //                     next = 0;
        //                     fetch = 1;
        //                     idu_dest = `idu_pc;
        //                     reg_write1 = `src_z;
        //                     reg_sel1 = `a;
        //                 end
        //                 default: `INVALID_STATE("ld a, [r16mem]")
        //                 endcase
        //             end else begin
        //                 //TEST: ld [r16mem], a
        //                 case ( state )
        //                 0: begin
        //                     next = 1;
        //                     addr = `addr_r16_mem;
        //                     dout = regs[`a];
        //                     write_mem = 1;
        //                     idu_op = IR[5]; //HL-
        //                     idu_dest = IR[5] ? `idu_hl : `idu_none;// HL+ || HL-
        //                 end
        //                 1: begin
        //                     next = 0;
        //                     addr = `addr_pc;
        //                     idu_dest = `idu_pc;
        //                     fetch = 1;
        //                 end
        //                 default: `INVALID_STATE("ld [r16mem], a")
        //                 endcase
        //             end
        //         end
        //         'b011: begin
        //             case ( state )
        //             //TEST: dec r16
        //             //TEST: inc r16
        //             0: begin
        //                 next = 1;
        //                 addr = `addr_r16;
        //                 idu_op = IR[3];
        //                 idu_dest = `idu_r16;
        //             end
        //             1: begin
        //                 next = 0;
        //                 addr = `addr_pc;
        //                 fetch = 1;
        //                 idu_dest = `idu_pc;
        //             end
        //             default: `INVALID_STATE(IR[3] ? "dec r16" : "inc r16")
        //             endcase
        //         end
        //         'b100: begin
        //             //TEST: inc r8
        //             alu_op = `ADD;
        //             if ( IR[5:3] == 3'b110 ) begin
        //                 case ( state )
        //                 0: begin
        //                     next = 1;
        //                     addr = `addr_r8_2;
        //                     writez = `wz_din;
        //                 end
        //                 1: begin
        //                     next = 2;
        //                     alu_in1 = z;
        //                     alu_in2 = 8'b1;

        //                     dout = alu_out;

        //                     reg_write1 = `src_alu_flags;
        //                     reg_sel1 = `f;
        //                     flags_mask = `fz | `fn | `fh;

        //                     addr = `addr_r8_2;
        //                     write_mem = 1;
        //                 end
        //                 2: begin
        //                     next = 0;
        //                     fetch = 1;
        //                     idu_dest = `idu_pc;
        //                 end
        //                 endcase
        //             end else begin
        //                 alu_in1 = regs[IR[5:3]];
        //                 alu_in1 = 8'b1;

        //                 reg_write1 = `src_alu_out;
        //                 reg_sel1 = IR[5:3];

        //                 reg_write2 = `src_alu_flags;
        //                 reg_sel2 = `f;
        //                 flags_mask = `fz | `fn | `fh;

        //                 fetch = 1;
        //                 idu_dest = `idu_pc;
        //             end
        //         end
        //         'b101: begin
        //             //TEST: dec r8
        //             alu_op = `SUB;
        //             if ( IR[5:3] == 3'b110 ) begin
        //                 case ( state )
        //                 0: begin
        //                     next = 1;
        //                     addr = `addr_r8_2;
        //                     writez = `wz_din;
        //                 end
        //                 1: begin
        //                     next = 2;
        //                     alu_in1 = z;
        //                     alu_in2 = 8'b1;

        //                     dout = alu_out;

        //                     reg_write1 = `src_alu_flags;
        //                     reg_sel1 = `f;
        //                     flags_mask = `fz | `fn | `fh;

        //                     addr = `addr_r8_2;
        //                     write_mem = 1;
        //                 end
        //                 2: begin
        //                     next = 0;
        //                     fetch = 1;
        //                     idu_dest = `idu_pc;
        //                 end
        //                 endcase
        //             end else begin
        //                 alu_in1 = regs[IR[5:3]];
        //                 alu_in1 = 8'b1;

        //                 reg_write1 = `src_alu_out;
        //                 reg_sel1 = IR[5:3];

        //                 reg_write2 = `src_alu_flags;
        //                 reg_sel2 = `f;
        //                 flags_mask = `fz | `fn | `fh;

        //                 fetch = 1;
        //                 idu_dest = `idu_pc;
        //             end
        //         end
        //         'b110: begin
        //             //TODO: ld r8, imm8
        //             case ( state )
        //             0: begin
        //                 next = 1;
        //                 writez = `wz_din;
        //                 idu_dest = `idu_pc;
        //             end
        //             1: begin
        //                 if ( IR[5:3] == 3'b110 ) begin
        //                     next = 2;
        //                     addr = `addr_r8_2;
        //                     dout = z;
        //                     write_mem = 1;
        //                 end else begin
        //                     next = 0;
        //                     reg_write1 = `src_z;
        //                     reg_sel1 = IR[5:3];
        //                     idu_dest = `idu_pc;
        //                 end
        //             end
        //             2: begin
        //                 next = 0;
        //                 fetch = 1;
        //                 idu_dest = `idu_pc;
        //             end
        //             endcase
        //         end
        //         'b111: begin
        //             case ( IR[5:3] )
        //             'b000:;//TODO: rlca
        //             'b001:;//TODO: rrca
        //             'b010:;//TODO: rla
        //             'b011:;//TODO: rra
        //             'b100:;//TODO: daa
        //             'b101:;//TODO: cpl
        //             'b110:;//TODO: scf
        //             'b111:;//TODO: ccf
        //             endcase
        //         end
        //         endcase
        //     end
        //     'b01: begin
        //         if ( IR[5:3] == 'b110 && IR[2:0] == 'b110 ) begin
        //             //TODO: halt
        //         end else begin
        //             //TODO: ld r8, r8
        //         end
        //     end
        //     'b10: begin
        //         case ( IR[5:3] )
        //         'b000: begin
        //             //TEST: add a, r8
        //             alu_op = `ADD;
        //             if ( IR[2:0] == 'b110 ) begin
        //                 case ( state )
        //                 0: begin
        //                     addr = `addr_r8;
        //                     writez = `wz_din;
        //                     next = 1;
        //                 end
        //                 1: begin
        //                     alu_in1 = regs[`a];
        //                     alu_in2 = z;

        //                     reg_write1 = `src_alu_out;
        //                     reg_sel1 = `a;

        //                     reg_write2 = `src_alu_flags;
        //                     reg_sel2 = `f;
        //                     flags_mask = `fz | `fn | `fh | `fc;

        //                     fetch = 1;
        //                     idu_dest = `idu_pc;

        //                     next = 0;
        //                 end
        //                 default: `INVALID_STATE("add a, [hl]")
        //                 endcase
        //             end else begin
        //                 alu_in1 = regs[`a];
        //                 alu_in2 = regs[IR[2:0]];

        //                 reg_write1 = `src_alu_out;
        //                 reg_sel1 = `a;

        //                 reg_write2 = `src_alu_flags;
        //                 reg_sel2 = `f;
        //                 flags_mask = `fz | `fn | `fh | `fc;

        //                 fetch = 1;
        //                 idu_dest = `idu_pc;
        //                 next = 0;
        //             end
        //         end
        //         'b001:;//TODO: adc a, r8
        //         'b010:;//TODO: sub a, r8
        //         'b011:;//TODO: sbc a, r8
        //         'b100:;//TODO: and a, r8
        //         'b101:;//TODO: xor a, r8
        //         'b110:;//TODO: or a, r8
        //         'b111:;//TODO: cp a, r8
        //         endcase
        //     end
        //     'b11: begin
        //         case ( IR[2:0] )
        //         'b000: begin
        //             casex ( IR[5:3] )
        //             'b0xx:;//TODO: ret cond
        //             'b100:;//TODO: ldh [imm8], a
        //             'b101:;//TODO: add sp, imm8
        //             'b110:;//TODO: ldh a, [imm8]
        //                 'b111:;//TODO: ld hl, sp + imm8
        //             endcase
        //         end
        //         'b001: begin
        //             casex ( IR[5:3] )
        //             'bxx0:;//TODO: pop r16stk
        //             'b001:;//TODO: ret
        //             'b011:;//TODO: reti
        //             'b101:;//TODO: jp hl
        //             'b111:;//TODO: ld sp, hl
        //             endcase
        //         end
        //         'b010: begin
        //             casex ( IR[5:3] )
        //             'b0xx:;//TODO: jp cond, imm16
        //             'b100:;//TODO: ldh [c], a
        //             'b101:;//TODO: ld [imm16], a
        //             'b110:;//TODO: ldh a, [c]
        //             'b111:;//TODO: ld a, [imm16]
        //             endcase
        //         end
        //         'b011: begin
        //             case ( IR[5:3] ) 
        //             'b000:;//TODO: jp imm16
        //             'b001:;//TODO: PREFIX
        //             'b110:;//TODO: di
        //             'b111:;//TODO: ei
        //             default:;//TODO: INVALID
        //             endcase
        //         end
        //         'b100: begin
        //             if ( IR[5] ) begin
        //                 //TODO: INVALID
        //             end else begin
        //                 //TODO: call cond, imm16
        //             end
        //         end
        //         'b101: begin
        //             casex ( IR[5:3] ) 
        //             'b001:;//TODO: call imm16
        //             'bxx0:;//TODO: push r16stk
        //             default:;//TODO: INVALID
        //             endcase
        //         end
        //         'b110: begin
        //             case ( IR[5:3] )
        //             'b000:;//TODO: add a, imm8
        //             'b001:;//TODO: adc a, imm8
        //             'b010:;//TODO: sub a, imm8
        //             'b011:;//TODO: sbc a, imm8
        //             'b100:;//TODO: and a, imm8
        //             'b101:;//TODO: xor a, imm8
        //             'b110:;//TODO: or a, imm8
        //             'b111:;//TODO: cp a, imm8
        //             endcase
        //         end
        //         'b111:;//TODO: rst tgt3
        //         endcase
        //     end
        //     endcase
        // end else begin
        //     case ( block )
        //     'b00: begin
        //         case ( IR[5:3] ) 
        //         'b000:;//TODO: rlc r8
        //         'b001:;//TODO: rrc r8
        //         'b010:;//TODO: rl r8
        //         'b011:;//TODO: rr r8
        //         'b100:;//TODO: sla r8
        //         'b101:;//TODO: sra r8
        //         'b110:;//TODO: swap r8
        //         'b111:;//TODO: srl r8
        //         endcase
        //     end
        //     'b01:;//TODO: bit b3, r8
        //     'b10:;//TODO: res b3, r8
        //     'b11:;//TODO: set b3, r8
        //     endcase
        // end
    // end

endmodule