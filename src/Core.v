`include "ALU_headers.vh"

module Core( clk, din, dout, addrbus, write_mem, wake );

    input clk;
    input wake;
    input [7:0] din;
    output reg [7:0] dout;
    output wire [15:0] addrbus;
    output reg write_mem = 0;
    
    reg [15:0] PC, SP;

    reg [7:0]
        IR, IE;
    reg IME;

    reg [7:0] z, w;
    reg [7:0] regs [0:9];
    `define b 0
    `define c 1
    `define d 2
    `define e 3
    `define h 4
    `define l 5
    `define f 6
    `define a 7
    `define x1 8
    `define x2 9
    //x not needed for isa, garbage reg
    `define bc {regs[`b], regs[`c]}
    `define de {regs[`d], regs[`e]}
    `define hl {regs[`h], regs[`l]}
    `define af {regs[`a], regs[`f]}
    `define wz {w, z}
    reg [3:0] reg_write1, reg_write2;
    reg [3:0] reg_sel1 = `x1, reg_sel2 = `x2;

    reg [7:0] alu_in1, alu_in2;
    reg [`OPWIDTH:0] alu_op;
    wire [7:0] alu_out;
    wire alu_z, alu_n, alu_c, alu_h;
    ALU alu_inst (alu_op, alu_in1, alu_in2, alu_out, regs[`f][4], {alu_z, alu_n, alu_h, alu_c});
    `define fz 4'b1000
    `define fn 4'b0100
    `define fh 4'b0010
    `define fc 4'b0001
    reg [3:0] flags_mask = `fz | `fn | `fh | `fc;
    wire[3:0] flags;
    assign flags[3] = flags_mask[3] ? alu_z : regs[`f][7];
    assign flags[2] = flags_mask[2] ? alu_n : regs[`f][6];
    assign flags[1] = flags_mask[1] ? alu_h : regs[`f][5];
    assign flags[0] = flags_mask[0] ? alu_c : regs[`f][4];

    wire[7:0] writesrc [0:5];
    `define src_none 0
    assign writesrc[`src_none] = 8'b0;
    `define src_alu_out 1
    assign writesrc[`src_alu_out] = alu_out;
    `define src_z 2
    assign writesrc[`src_z] = z;
    `define src_alu_flags 3
    assign writesrc[`src_alu_flags] = {flags, 4'b0000};
    `define src_r8 4
    assign writesrc[`src_r8] = regs[IR[2:0]];
    `define src_r8_2 5
    assign writesrc[`src_r8_2] = regs[IR[5:3]];

    `define r16_none 0
    `define r16_regs 1
    `define r16_wz 2
    reg [1:0] r16_sel = `r16_none;
    reg stk = 0;
    reg [15:0] r16_write = 0;

    wire [15:0] r16 [0:3], r16stk [0:3], r16mem [0:3];
    assign r16[0] = `bc;
    assign r16stk[0] = `bc;
    assign r16mem[0] = `bc;
    assign r16[1] = `de;
    assign r16stk[1] = `de;
    assign r16mem[1] = `de;
    assign r16[2] = `hl;
    assign r16stk[2] = `hl;
    assign r16mem[2] = `hl;
    assign r16[3] = SP;
    assign r16stk[3] = `af;
    assign r16mem[3] = `hl;

    wire [15:0] addrsrcs [0:6];
    `define addr_pc 0
    assign addrsrcs[`addr_pc] = PC;
    `define addr_pch 1
    assign addrsrcs[`addr_pch] = {8'b0, PC[15:8]};
    `define addr_wz 2
    assign addrsrcs[`addr_wz] = `wz;
    `define addr_r8 3
    assign addrsrcs[`addr_r8] = regs[IR[2:0]];
    `define addr_r8_2 4
    assign addrsrcs[`addr_r8_2] = regs[IR[5:3]];
    `define addr_r16 5
    assign addrsrcs[`addr_r16] = r16[IR[5:4]];
    `define addr_r16_mem 6
    assign addrsrcs[`addr_r16_mem] = r16mem[IR[5:4]];

    reg [2:0] addr = `addr_pc;
    assign addrbus = addrsrcs[addr];

    `define inc 0
    `define dec 1
    reg idu_op = `inc;
    `define idu_none 0
    `define idu_pc 1
    `define idu_wz 2
    `define idu_r16 3
    `define idu_hl 4
    `define idu_w 5
    reg [2:0] idu_dest;
    wire [15:0] idu;
    assign idu = idu_op ? addrbus - 1 : addrbus + 1;

    `define wz_na 0
    `define wz_alu 1
    `define wz_din 2
    `define wz_idu 3
    reg [1:0] writez = `wz_na, writew = `wz_na;
    wire [7:0] zsrcs [0:2], wsrcs [0:2];
    assign zsrcs[`wz_na] = z;
    assign wsrcs[`wz_na] = w;
    assign zsrcs[`wz_alu] = alu_out;
    assign wsrcs[`wz_alu] = alu_out;
    assign zsrcs[`wz_din] = din;
    assign wsrcs[`wz_din] = din;
    assign zsrcs[`wz_idu] = idu;
    assign wsrcs[`wz_idu] = idu;
    
    `define cond_nz 0
    `define cond_z 1
    `define cond_nc 2
    `define cond_c 3
    `define cond_none 4
    reg [1:0] cc = `cond_none;
    reg cond = 0;
    wire cond_check [0:3];
    assign cond_check[`cond_nz] = ~alu_z;
    assign cond_check[`cond_z] = alu_z;
    assign cond_check[`cond_nc] = ~alu_c;
    assign cond_check[`cond_c] = alu_c;
    assign cond_check[`cond_none] = cond;

    reg [2:0] state, next;

    wire [1:0] block;
    assign block = IR[7:6];

    reg prefix = 0, fetch = 0;

    `define INVALID_STATE(mnemonic) $display("---\nERROR\ninstruction:\n\t%s\nhas no defined state:\n\t%d\n", mnemonic, state);

    integer i;
    initial begin
        state = 0;
        PC = -1;
        IR = 0;
        SP = 16'habcd;
        for (i = 0; i < 10; i = i + 1) regs[i] = 0;
        `wz = 0;
    end

    always @ ( posedge clk ) begin
        state <= next;
        if (fetch) IR <= din;
        regs[reg_sel1] <= writesrc[reg_write1];
        regs[reg_sel2] <= writesrc[reg_write2];

        z <= zsrcs[writez];
        w <= wsrcs[writew];

        case ( r16_sel )
        `r16_none:;
        `r16_regs: begin
            case ( IR[5:4] )
            0: `bc <= r16_write;
            1: `de <= r16_write;
            2: `hl <= r16_write;
            3: begin
                if (stk)
                    `af <= r16_write;
                else
                    SP <= r16_write;
            end
            endcase
        end
        `r16_wz: `wz <= r16_write;
        endcase

        cond <= cond_check[cc];

        case ( idu_dest )
        `idu_pc: PC <= idu;
        `idu_wz: `wz <= idu;
        `idu_hl: `hl <= idu;
        `idu_r16: begin
            case ( IR[5:4] )
            0: `bc <= r16_write;
            1: `de <= r16_write;
            2: `hl <= r16_write;
            3: begin
                if (stk)
                    `af <= r16_write;
                else
                    SP <= r16_write;
            end
            endcase
        end
        `idu_w: w <= idu[7:0];
        `idu_none:;
        default:;
        endcase
    end

    always @* begin
        next = 0;
        fetch = 0;
        addr = `addr_pc;
        write_mem = 0;
        writez = `wz_na;
        writew = `wz_na;
        reg_sel1 = `x1;
        reg_sel2 = `x2;
        reg_write1 = `src_none;
        reg_write2 = `src_none;
        r16_sel = `r16_none;
        idu_dest = `idu_none;
        idu_op = `inc;
        cc = `cond_none;
        if ( !prefix ) begin
            case ( block )
            'b00: begin
                case ( IR[2:0] )
                'b000: begin
                    casex ( IR[5:3] )
                    'b000: begin
                        //TESTED: nop
                        next = 0;
                        r16_write = PC + 1;
                        idu_dest = `idu_pc;
                        fetch = 1;
                    end
                    'b001: begin 
                        //TESTED: ld [imm16], sp
                        case ( state )
                        0: begin
                            next = 1;
                            writez = `wz_din;
                            idu_dest = `idu_pc;
                        end
                        1: begin
                            next= 2;
                            writew = `wz_din;
                            idu_dest = `idu_pc;
                        end
                        2: begin
                            next = 3;
                            addr = `addr_wz;
                            dout = SP[7:0];
                            write_mem = 1;
                            idu_dest = `idu_wz;
                        end
                        3: begin
                            next = 4;
                            addr = `addr_wz;
                            write_mem = 1;
                            dout = SP[15:8];
                        end
                        4: begin 
                            next = 0;
                            fetch = 1;
                            idu_dest = `idu_pc;
                        end
                        default: `INVALID_STATE("ld [imm16], sp")
                        endcase
                    end
                    'b010:; //TODO: stop
                    'b011: begin
                        //TEST: jr imm8
                        case (state)
                        0: begin
                            next = 1;
                            writez = `wz_din;
                        end
                        1: begin
                            next = 2;
                            alu_op = `ADD;
                            alu_in1 = z;
                            alu_in2 = PC[7:0];

                            writez = `wz_alu;

                            addr = `addr_pch;
                            if (alu_c && !z[7])
                                idu_op = `inc;
                            else
                                idu_op = `dec;
                            idu_dest = (alu_c ^ z[7]) ? `idu_w : `idu_none;
                        end
                        2: begin
                            next = 0;
                            addr = `addr_wz;
                            fetch = 1;
                            idu_dest = `idu_pc;
                        end
                        default: `INVALID_STATE("jr imm8")
                        endcase
                    end
                    'b1xx: begin
                        //TEST: jr cond, imm8
                        case ( state ) 
                        0: begin
                            next = 1;
                            writez = `wz_din;
                            cc = IR[4:3];
                        end
                        1: begin
                            if (cond) begin
                                next = 2;
                                alu_op = `ADD;
                                alu_in1 = z;
                                alu_in2 = PC[7:0];

                                writez = `wz_alu;

                                addr = `addr_pch;
                                if (alu_c && !z[7])
                                    idu_op = `inc;
                                else
                                    idu_op = `dec;
                                idu_dest = (alu_c ^ z[7]) ? `idu_w : `idu_none;
                            end else begin
                                next = 0;
                                fetch = 1;
                                idu_dest = `idu_pc;
                            end
                        end
                        2: begin
                            next = 0;
                            addr = `addr_wz;
                            fetch = 1;
                            idu_dest = `idu_wz;
                        end
                        default: `INVALID_STATE("jr cond, imm8")
                        endcase
                    end
                    endcase
                end
                'b001: begin
                    if ( IR[3] ) begin
                        //TEST: add hl, r16
                        case ( state )
                        0: begin
                            next = 1;
                            alu_op = `ADD;
                            alu_in1 = regs[`l];
                            alu_in2 = r16[IR[5:4]][7:0];

                            reg_write1 = `src_alu_out;
                            reg_sel1 = `l;

                            reg_write2 = `src_alu_flags;
                            reg_sel2 = `f;
                            flags_mask = `fn | `fh | `fc;
                        end
                        1: begin
                            next = 0;
                            alu_op = `ADC;
                            alu_in1 = regs[`h];
                            alu_in2 = r16[IR[5:4]][15:8];

                            reg_write1 = `src_alu_out;
                            reg_sel1 = `h;

                            reg_write2 = `src_alu_flags;
                            reg_sel2 = `f;
                            flags_mask = `fn | `fh | `fc;

                            fetch = 1;
                            idu_dest = `idu_pc;
                        end
                        default: `INVALID_STATE("add hl, r16")
                        endcase
                    end else begin
                        //TEST: ld r16, imm16
                        case ( state )
                        0: begin
                            next = 1;
                            writez = `wz_din;
                            idu_dest = `idu_pc;
                        end
                        1: begin
                            next = 2;
                            writew = `wz_din;
                            idu_dest = `idu_pc;
                        end
                        2: begin
                            next = 0;
                            fetch = 1;
                            idu_dest = `idu_pc;
                            r16_write = `wz;
                            r16_sel = `r16_regs;
                        end
                        default: `INVALID_STATE("ld r16, imm16")
                        endcase
                    end
                end
                'b010: begin
                    if ( IR[3] ) begin
                        //TEST: ld a, [r16mem]
                        case ( state )
                        0: begin
                            next = 1;
                            addr = `addr_r16_mem;
                            writez = `wz_din;
                            idu_op = IR[5]; //HL-
                            idu_dest = IR[5] ? `idu_hl : `idu_none;// HL+ || HL-
                        end
                        1: begin
                            next = 0;
                            fetch = 1;
                            idu_dest = `idu_pc;
                            reg_write1 = `src_z;
                            reg_sel1 = `a;
                        end
                        default: `INVALID_STATE("ld a, [r16mem]")
                        endcase
                    end else begin
                        //TEST: ld [r16mem], a
                        case ( state )
                        0: begin
                            next = 1;
                            addr = `addr_r16_mem;
                            dout = regs[`a];
                            write_mem = 1;
                            idu_op = IR[5]; //HL-
                            idu_dest = IR[5] ? `idu_hl : `idu_none;// HL+ || HL-
                        end
                        1: begin
                            next = 0;
                            addr = `addr_pc;
                            idu_dest = `idu_pc;
                            fetch = 1;
                        end
                        default: `INVALID_STATE("ld [r16mem], a")
                        endcase
                    end
                end
                'b011: begin
                    case ( state )
                    //TEST: dec r16
                    //TEST: inc r16
                    0: begin
                        next = 1;
                        addr = `addr_r16;
                        idu_op = IR[3];
                        idu_dest = `idu_r16;
                    end
                    1: begin
                        next = 0;
                        addr = `addr_pc;
                        fetch = 1;
                        idu_dest = `idu_pc;
                    end
                    default: `INVALID_STATE(IR[3] ? "dec r16" : "inc r16")
                    endcase
                end
                'b100: begin
                    //TODO: inc r8
                    alu_op = `ADD;
                    if ( IR[5:3] == 3'b110 ) begin
                        case ( state )
                        0: begin
                            next = 1;
                            addr = `addr_r8_2;
                            writez = `wz_din;
                        end
                        1: begin
                            next = 2;
                            alu_in1 = z;
                            alu_in2 = 8'b1;

                            dout = alu_out;

                            reg_write1 = `src_alu_flags;
                            reg_sel1 = `f;
                            flags_mask = `fz | `fn | `fh;

                            addr = `addr_r8_2;
                            write_mem = 1;
                        end
                        2: begin
                            next = 0;
                            fetch = 1;
                            idu_dest = `idu_pc;
                        end
                        endcase
                    end else begin
                        alu_in1 = regs[IR[5:3]];
                        alu_in1 = 8'b1;

                        reg_write1 = `src_alu_out;
                        reg_sel1 = IR[5:3];

                        reg_write2 = `src_alu_flags;
                        reg_sel2 = `f;
                        flags_mask = `fz | `fn | `fh;

                        fetch = 1;
                        idu_dest = `idu_pc;
                    end
                end
                'b101: begin
                    //TODO: dec r8
                    alu_op = `SUB;
                    if ( IR[5:3] == 3'b110 ) begin
                        case ( state )
                        0: begin
                            next = 1;
                            addr = `addr_r8_2;
                            writez = `wz_din;
                        end
                        1: begin
                            next = 2;
                            alu_in1 = z;
                            alu_in2 = 8'b1;

                            dout = alu_out;

                            reg_write1 = `src_alu_flags;
                            reg_sel1 = `f;
                            flags_mask = `fz | `fn | `fh;

                            addr = `addr_r8_2;
                            write_mem = 1;
                        end
                        2: begin
                            next = 0;
                            fetch = 1;
                            idu_dest = `idu_pc;
                        end
                        endcase
                    end else begin
                        alu_in1 = regs[IR[5:3]];
                        alu_in1 = 8'b1;

                        reg_write1 = `src_alu_out;
                        reg_sel1 = IR[5:3];

                        reg_write2 = `src_alu_flags;
                        reg_sel2 = `f;
                        flags_mask = `fz | `fn | `fh;

                        fetch = 1;
                        idu_dest = `idu_pc;
                    end
                end
                'b110:;//TODO: ld r8, imm8
                'b111: begin
                    case ( IR[5:3] )
                    'b000:;//TODO: rlca
                    'b001:;//TODO: rrca
                    'b010:;//TODO: rla
                    'b011:;//TODO: rra
                    'b100:;//TODO: daa
                    'b101:;//TODO: cpl
                    'b110:;//TODO: scf
                    'b111:;//TODO: ccf
                    endcase
                end
                endcase
            end
            'b01: begin
                if ( IR[5:3] == 'b110 && IR[2:0] == 'b110 ) begin
                    //TODO: halt
                end else begin
                    //TODO: ld r8, r8
                end
            end
            'b10: begin
                case ( IR[5:3] )
                'b000: begin
                    //TEST: add a, r8
                    alu_op = `ADD;
                    if ( IR[2:0] == 'b110 ) begin
                        case ( state )
                        0: begin
                            addr = `addr_r8;
                            writez = `wz_din;
                            next = 1;
                        end
                        1: begin
                            alu_in1 = regs[`a];
                            alu_in2 = z;

                            reg_write1 = `src_alu_out;
                            reg_sel1 = `a;

                            reg_write2 = `src_alu_flags;
                            reg_sel2 = `f;
                            flags_mask = `fz | `fn | `fh | `fc;

                            fetch = 1;
                            idu_dest = `idu_pc;

                            next = 0;
                        end
                        default: `INVALID_STATE("add a, [hl]")
                        endcase
                    end else begin
                        alu_in1 = regs[`a];
                        alu_in2 = regs[IR[2:0]];

                        reg_write1 = `src_alu_out;
                        reg_sel1 = `a;

                        reg_write2 = `src_alu_flags;
                        reg_sel2 = `f;
                        flags_mask = `fz | `fn | `fh | `fc;

                        fetch = 1;
                        idu_dest = `idu_pc;
                        next = 0;
                    end
                end
                'b001:;//TODO: adc a, r8
                'b010:;//TODO: sub a, r8
                'b011:;//TODO: sbc a, r8
                'b100:;//TODO: and a, r8
                'b101:;//TODO: xor a, r8
                'b110:;//TODO: or a, r8
                'b111:;//TODO: cp a, r8
                endcase
            end
            'b11: begin
                case ( IR[2:0] )
                'b000: begin
                    casex ( IR[5:3] )
                    'b0xx:;//TODO: ret cond
                    'b100:;//TODO: ldh [imm8], a
                    'b101:;//TODO: add sp, imm8
                    'b110:;//TODO: ldh a, [imm8]
                        'b111:;//TODO: ld hl, sp + imm8
                    endcase
                end
                'b001: begin
                    casex ( IR[5:3] )
                    'bxx0:;//TODO: pop r16stk
                    'b001:;//TODO: ret
                    'b011:;//TODO: reti
                    'b101:;//TODO: jp hl
                    'b111:;//TODO: ld sp, hl
                    endcase
                end
                'b010: begin
                    casex ( IR[5:3] )
                    'b0xx:;//TODO: jp cond, imm16
                    'b100:;//TODO: ldh [c], a
                    'b101:;//TODO: ld [imm16], a
                    'b110:;//TODO: ldh a, [c]
                    'b111:;//TODO: ld a, [imm16]
                    endcase
                end
                'b011: begin
                    case ( IR[5:3] ) 
                    'b000:;//TODO: jp imm16
                    'b001:;//TODO: PREFIX
                    'b110:;//TODO: di
                    'b111:;//TODO: ei
                    default:;//TODO: INVALID
                    endcase
                end
                'b100: begin
                    if ( IR[5] ) begin
                        //TODO: INVALID
                    end else begin
                        //TODO: call cond, imm16
                    end
                end
                'b101: begin
                    casex ( IR[5:3] ) 
                    'b001:;//TODO: call imm16
                    'bxx0:;//TODO: push r16stk
                    default:;//TODO: INVALID
                    endcase
                end
                'b110: begin
                    case ( IR[5:3] )
                    'b000:;//TODO: add a, imm8
                    'b001:;//TODO: adc a, imm8
                    'b010:;//TODO: sub a, imm8
                    'b011:;//TODO: sbc a, imm8
                    'b100:;//TODO: and a, imm8
                    'b101:;//TODO: xor a, imm8
                    'b110:;//TODO: or a, imm8
                    'b111:;//TODO: cp a, imm8
                    endcase
                end
                'b111:;//TODO: rst tgt3
                endcase
            end
            endcase
        end else begin
            case ( block )
            'b00: begin
                case ( IR[5:3] ) 
                'b000:;//TODO: rlc r8
                'b001:;//TODO: rrc r8
                'b010:;//TODO: rl r8
                'b011:;//TODO: rr r8
                'b100:;//TODO: sla r8
                'b101:;//TODO: sra r8
                'b110:;//TODO: swap r8
                'b111:;//TODO: srl r8
                endcase
            end
            'b01:;//TODO: bit b3, r8
            'b10:;//TODO: res b3, r8
            'b11:;//TODO: set b3, r8
            endcase
        end
    end

endmodule