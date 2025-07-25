`include "Control_headers.vh"
`include "ALU_headers.vh"
`include "IDU_headers.vh"
`include "RegFile_headers.vh"

module ControlUnit(
        clk, wake,
        IR, fetch,
        r1,
        r2,
        rd,
        ctr,
        data_sel,
        addrh, addrl,
        rd_idu,
        writeback,
        alu_op, flag_mask, idu_op,
        cc, cc_true,
        intr_req
    );
    input wire          clk, wake;
    input wire          intr_req;
    input wire  [7:0]   IR;
    output reg          writeback = 0;
    output reg          data_sel = `din;
    output reg  [3:0]   r1 = `ctr, r2 = `ctr, rd = `ctr, addrh = `pch, addrl = `pcl;
    output reg  [7:0]   ctr;
    output reg  [2:0]   rd_idu = `ff;
    output reg  [`ALU_opwidth:0]   alu_op;
    output reg  [`IDU_opwidth:0]   idu_op;
    output reg  [4:0]   flag_mask;
    output reg          fetch = 0;
    output reg  [1:0]   cc;
    input wire          cc_true;
    
    reg [5:0] state = `s0, next = `s0;
    reg prefix = 0;

    reg [7:0] IE = 0;
    reg IME;

    wire [`IDU_opwidth:0] r16mem_op [0:3];
    assign r16mem_op[0] = `PAS; // [bc]
    assign r16mem_op[1] = `PAS; // [de]
    assign r16mem_op[2] = `INC; // [hl+]
    assign r16mem_op[3] = `DEC; // [hl-]
    wire [2:0] r16mem_rd [0:3];
    assign r16mem_rd[0] = `bc; // [bc]
    assign r16mem_rd[1] = `de; // [de]
    assign r16mem_rd[2] = `hl; // [hl+]
    assign r16mem_rd[3] = `hl; // [hl-]

    wire [7:0] MSB [0:3], LSB [0:3];
    assign MSB[`bc] = `b;
    assign LSB[`bc] = `c;
    assign MSB[`de] = `d;
    assign LSB[`de] = `e;
    assign MSB[`hl] = `h;
    assign LSB[`hl] = `l;
    assign MSB[`sp] = `sph;
    assign LSB[`sp] = `spl;

    always @ ( posedge clk ) begin
        state <= next;
    end

    `define executing(mnemonic) $display("%s\t-\tstate: %6b", mnemonic, state);

    always @* begin
        next = `s0;
        fetch = 0;
        writeback = 0;
        r1 = `ctr;
        r2 = `ctr;
        ctr = 0;
        rd = `ctr; // ignore writes to ctr
        addrh = `pch;
        addrl = `pcl;
        rd_idu = `ff; // ignore writes to ff
        alu_op = `PAS;
        idu_op = `INC;
        cc = 0;
        flag_mask = 0;
        data_sel = `din;
        // begin state logic

        casex ( IR )
        'b00_000_000: begin
            $display("nop");
            // nop
            rd_idu = `pc;
            fetch = 1;
        end
        'b00_xx0_001: begin
            // ld r16, imm16
            `executing("ld r16, imm16")
            case ( state )
            `s0: begin
                next = `s1;
                rd_idu = `pc;
                rd = LSB[IR[5:4]];
            end
            `s1: begin
                next = `s2;
                rd_idu = `pc;
                rd = MSB[IR[5:4]];
            end
            `s2: begin
                rd_idu = `pc;
                fetch = 1;
            end
            endcase
        end
        'b00_xx0_010: begin
            `executing("ld [r16mem], a")
            case ( state )
            `s0: begin
                next = `s1;
                addrh = MSB[IR[5:4]];
                addrl = LSB[IR[5:4]];
                r1 = `a;
                alu_op = `PAS;
                idu_op = r16mem_op[IR[5:4]];
                rd_idu = r16mem_rd[IR[5:4]];
                writeback = 1;
            end
            `s1: begin
                rd_idu = `pc;
                fetch = 1;
            end
            endcase
        end
        'b00_xx0_011: begin
            $display("inc r16");
            case ( state )
            `s0: begin
                next = `s1;
                addrh = MSB[IR[5:4]];
                addrl = LSB[IR[5:4]];
                rd_idu = IR[5:4];
            end
            `s1: begin
                rd_idu = `pc;
                fetch = 1;
            end
            endcase
        end
        'b00_xxx_100: begin
            $display("inc r8");
            case ( state )
            `s0: begin
                if ( IR[5:3] == 'b110 ) begin
                    next = `s1;
                    addrh = `h;
                    addrl = `l;
                    rd = `z;
                end else begin
                    next = `s2;
                    rd = IR[5:3];
                    r1 = IR[5:3];
                    r2 = `one;
                    alu_op = `ADD;
                    data_sel = `alu;
                    flag_mask = `fz | `fn | `fh;
                end
            end
            `s1: begin
                next = `s2;
                addrh = `h;
                addrl = `l;
                alu_op = `ADD;
                r1 = `z;
                r2 = `one;
                writeback = 1;
            end
            `s2: begin
                rd_idu = `pc;
                fetch = 1;
            end
            endcase
        end
        'b00_xxx_101: begin
            $display("dec r8");
            case ( state )
            `s0: begin
                if ( IR[5:3] == 'b110 ) begin
                    next = `s1;
                    addrh = `h;
                    addrl = `l;
                    rd = `z;
                end else begin
                    next = `s2;
                    rd = IR[5:3];
                    r1 = IR[5:3];
                    r2 = `one;
                    alu_op = `SUB;
                    data_sel = `alu;
                    flag_mask = `fz | `fn | `fh;
                end
            end
            `s1: begin
                next = `s2;
                addrh = `h;
                addrl = `l;
                alu_op = `SUB;
                r1 = `z;
                r2 = `one;
                writeback = 1;
            end
            `s2: begin
                rd_idu = `pc;
                fetch = 1;
            end
            endcase
        end
        'b00_xxx_110: begin
            $display("ld r8, imm8");
            case ( state )
            `s0: begin
                rd_idu = `pc;
                if ( IR[5:3] == 'b110 ) begin
                    next = `s1;
                    rd = `z;
                end else begin
                    next = `s2;
                    rd = IR[5:3];
                end
            end
            `s1: begin
                next = `s2;
                r1 = `z;
                addrh = `h;
                addrl = `l;
                writeback = 1;
            end
            `s2: begin
                rd_idu = `pc;
                fetch = 1;
            end
            endcase
        end
        'b00_xxx_111: begin
            r1 = `a;
            r2 = `ctr;
            ctr = `a;
            rd = `a;
            alu_op = {1'b1, IR[5:3]};
            rd_idu = `pc;
            fetch = 1;
        end
        'b00_001_000: begin
            `executing("ld [imm16], sp")
            case ( state )
            `s0: begin
                next = `s1;
                rd = `z;
                data_sel = `din;
                rd_idu = `pc;
            end
            `s1: begin
                next = `s2;
                rd = `w;
                data_sel = `din;
                rd_idu = `pc;
            end
            `s2: begin
                next = `s3;
                addrh = `w;
                addrl = `z;
                r1 = `spl;
                writeback = 1;
                rd_idu = `wz;
            end
            `s3: begin
                next = `s4;
                addrh = `w;
                addrl = `z;
                r1 = `sph;
                writeback = 1;
            end
            `s4: begin
                rd_idu = `pc;
                fetch = 1;
            end
            endcase
        end
        'b00_xx1_001: begin
            `executing("add hl, r16")
            data_sel = `alu;
            flag_mask = `fn | `fh | `fc;
            case ( state )
            `s0: begin
                next = `s1;
                alu_op = `ADD;
                r1 = `l;
                r2 = LSB[IR[5:4]];
                rd = `l;
            end
            `s1: begin
                alu_op = `ADC;
                r1 = `h;
                r2 = MSB[IR[5:4]];
                rd = `h;

                addrh = `pch;
                addrl = `pcl;
                rd_idu = `pc;
                fetch = 1;
            end
            endcase
        end
        'b00_xx1_010: begin
            $display("ld a, [r16mem]");
            case ( state )
            `s0: begin
                next = `s1;
                addrh = MSB[IR[5:4]];
                addrl = LSB[IR[5:4]];
                data_sel = `din;
                idu_op = r16mem_op[IR[5:4]];
                rd_idu = r16mem_rd[IR[5:4]];
                rd = `a;
            end
            `s1: begin
                rd_idu = `pc;
                fetch = 1;
            end
            endcase
        end
        'b00_xx1_011: begin
            $display("dec r16");
            case ( state )
            `s0: begin
                next = `s1;
                addrh = MSB[IR[5:4]];
                addrl = LSB[IR[5:4]];
                rd_idu = IR[5:4];
                idu_op = `DEC;
            end
            `s1: begin
                rd_idu = `pc;
                fetch = 1;
            end
            endcase
        end
        'b00_010_000: begin
            `executing("stop")
            // temporary (possibly incorrect) implementation of stop
            case ( state )
                `s0: begin
                    if ( wake ) begin
                        rd_idu = `pc;
                        fetch = 1;
                    end else begin
                        next = `s1;
                    end
                end
                `s1: $finish();
            endcase
        end
        'b00_011_000: begin
            `executing("jr imm8")
            case ( state )
            `s0: begin
                next = `s1;
                data_sel = `din;
                rd = `z;
                rd_idu = `pc;
            end
            `s1: begin
                next = `s2;
                data_sel = `alu;
                alu_op = `ADD;
                r1 = `pcl;
                r2 = `z;
                rd = `z;
                idu_op = `ADJ;
                addrl = `pch;
                addrh = `ctr;
                ctr = 8'b0;
            end
            `s2: begin
                addrh = `w;
                addrl = `z;
                rd_idu = `pc;
                fetch = 1;
            end
            endcase
        end
        'b00_1xx_000: begin
            `executing("jr cond, imm8")
            case ( state )
            `s0: begin
                data_sel = `din;
                rd = `z;
                rd_idu = `pc;
                cc = IR[4:3];
                if ( cc_true ) begin
                    next = `s2;
                end else begin
                    next = `s1;
                end
            end
            `s1: begin
                rd_idu = `pc;
                fetch = 1;
            end
            `s2: begin
                next = `s3;
                data_sel = `alu;
                alu_op = `ADD;
                r1 = `pcl;
                r2 = `z;
                rd = `z;
                idu_op = `ADJ;
                addrl = `pch;
                addrh = `ctr;
                ctr = 8'b0;
            end
            `s3: begin
                addrh = `w;
                addrl = `z;
                rd_idu = `pc;
                fetch = 1;
            end
            endcase
        end
        endcase

    end


endmodule
