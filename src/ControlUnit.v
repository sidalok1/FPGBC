
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
    
    `include "RegFile_params.vh"
    `include "Control_params.vh"
    `include "IDU_params.vh"
    `include "ALU_params.vh"

    input wire          clk, wake;
    input wire          intr_req;
    input wire  [7:0]   IR;
    output reg          writeback = 0;
    output reg          data_sel = DIN;
    output reg  [3:0]   r1 = CTR, r2 = CTR, rd = CTR, addrh = PCH, addrl = PCL;
    output reg  [7:0]   ctr;
    output reg  [2:0]   rd_idu = FF;
    output reg  [ALU_OPWIDTH:0]   alu_op;
    output reg  [IDU_OPWIDTH:0]   idu_op;
    output reg  [4:0]   flag_mask;
    output reg          fetch = 0;
    output reg  [1:0]   cc;
    input wire          cc_true;

    
    reg [5:0] state = S0, next = S0;
    reg prefix = 0;

    reg [7:0] IE = 0;
    reg IME;

    wire [IDU_OPWIDTH:0] r16mem_op [0:3];
    assign r16mem_op[0] = ZER; // [bc]
    assign r16mem_op[1] = ZER; // [de]
    assign r16mem_op[2] = INC; // [hl+]
    assign r16mem_op[3] = DEC; // [hl-]
    wire [2:0] r16mem_rd [0:3];
    assign r16mem_rd[0] = BC; // [bc]
    assign r16mem_rd[1] = DE; // [de]
    assign r16mem_rd[2] = HL; // [hl+]
    assign r16mem_rd[3] = HL; // [hl-]

    wire [7:0] MSB [0:3], LSB [0:3];
    assign MSB[BC] = B;
    assign LSB[BC] = C;
    assign MSB[DE] = D;
    assign LSB[DE] = E;
    assign MSB[HL] = H;
    assign LSB[HL] = L;
    assign MSB[SP] = SPH;
    assign LSB[SP] = SPL;

    wire [7:0] MSBm [0:3], LSBm [0:3];
    assign MSBm[0] = B;
    assign LSBm[0] = C;
    assign MSBm[1] = D;
    assign LSBm[1] = E;
    assign MSBm[2] = H;
    assign LSBm[2] = L;
    assign MSBm[3] = H;
    assign LSBm[3] = L;

    wire halt;
    assign halt = IR[5:0] == 6'b110_110;

    always @ ( posedge clk ) begin
        state <= next;
    end

    always @* begin
        next = S0;
        fetch = 0;
        writeback = 0;
        r1 = CTR;
        r2 = CTR;
        ctr = 0;
        rd = CTR; // ignore writes to ctr
        addrh = PCH;
        addrl = PCL;
        rd_idu = FF; // ignore writes to ff
        alu_op = PAS;
        idu_op = INC;
        cc = 0;
        flag_mask = 0;
        data_sel = DIN;
        // begin state logic

        casex ( IR )
        'b00_000_000: begin
            $display("nop");
            // nop
            rd_idu = PC;
            fetch = 1;
        end
        'b00_xx0_001: begin
            // ld r16, imm16
            `executing("ld r16, imm16")
            case ( state )
            S0: begin
                next = S1;
                rd_idu = PC;
                rd = LSB[IR[5:4]];
            end
            S1: begin
                next = S2;
                rd_idu = PC;
                rd = MSB[IR[5:4]];
            end
            S2: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b00_xx0_010: begin
            `executing("ld [r16mem], a")
            case ( state )
            S0: begin
                next = S1;
                addrh = MSBm[IR[5:4]];
                addrl = LSBm[IR[5:4]];
                r1 = A;
                alu_op = PAS;
                idu_op = r16mem_op[IR[5:4]];
                rd_idu = r16mem_rd[IR[5:4]];
                writeback = 1;
            end
            S1: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b00_xx0_011: begin
            $display("inc r16");
            case ( state )
            S0: begin
                next = S1;
                addrh = MSB[IR[5:4]];
                addrl = LSB[IR[5:4]];
                rd_idu = IR[5:4];
            end
            S1: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b00_xxx_100: begin
            $display("inc r8");
            case ( state )
            S0: begin
                if ( IR[5:3] == 'b110 ) begin
                    next = S1;
                    addrh = H;
                    addrl = L;
                    rd = Z;
                end else begin
                    next = S2;
                    rd = IR[5:3];
                    r1 = IR[5:3];
                    r2 = ONE;
                    alu_op = ADD;
                    data_sel = ALU;
                    flag_mask = ZFLAG | NFLAG | HFLAG ;
                end
            end
            S1: begin
                next = S2;
                addrh = H;
                addrl = L;
                alu_op = ADD;
                data_sel = ALU;
                r1 = Z;
                r2 = ONE;
                flag_mask = ZFLAG | NFLAG | HFLAG ;
                writeback = 1;
            end
            S2: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b00_xxx_101: begin
            $display("dec r8");
            case ( state )
            S0: begin
                if ( IR[5:3] == 'b110 ) begin
                    next = S1;
                    addrh = H;
                    addrl = L;
                    rd = Z;
                end else begin
                    next = S2;
                    rd = IR[5:3];
                    r1 = IR[5:3];
                    r2 = ONE;
                    alu_op = SUB;
                    data_sel = ALU;
                    flag_mask = ZFLAG | NFLAG | HFLAG ;
                end
            end
            S1: begin
                next = S2;
                addrh = H;
                addrl = L;
                alu_op = SUB;
                data_sel = ALU;
                r1 = Z;
                r2 = ONE;
                flag_mask = ZFLAG | NFLAG | HFLAG ;
                writeback = 1;
            end
            S2: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b00_xxx_110: begin
            $display("ld r8, imm8");
            case ( state )
            S0: begin
                rd_idu = PC;
                if ( IR[5:3] == 'b110 ) begin
                    next = S1;
                    rd = Z;
                end else begin
                    next = S2;
                    rd = IR[5:3];
                end
            end
            S1: begin
                next = S2;
                r1 = Z;
                addrh = H;
                addrl = L;
                writeback = 1;
            end
            S2: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b00_xxx_111: begin
            r1 = A;
            r2 = CTR;
            data_sel = ALU;
            ctr = A;
            rd_idu = PC;
            fetch = 1;
            casex ( IR[5:3] )
            'b0xx: begin
                rd = A;
                alu_op = {2'b01, IR[5:3]};
                flag_mask = ALLFLAG;
            end
            'b100: begin
                rd = A;
                alu_op = DAA;
                flag_mask = ZFLAG | HFLAG | CFLAG ;
            end
            'b101: begin
                rd = A;
                alu_op = CPL;
                flag_mask = NFLAG | HFLAG ;
            end
            'b110: begin
                alu_op = SCF;
                flag_mask = ZFLAG | HFLAG | CFLAG ;
            end
            'b111: begin
                alu_op = CCF;
                flag_mask = ZFLAG | HFLAG | CFLAG ;
            end
            endcase
        end
        'b00_001_000: begin
            `executing("ld [imm16], sp")
            case ( state )
            S0: begin
                next = S1;
                rd = Z;
                data_sel = DIN;
                rd_idu = PC;
            end
            S1: begin
                next = S2;
                rd = W;
                data_sel = DIN;
                rd_idu = PC;
            end
            S2: begin
                next = S3;
                addrh = W;
                addrl = Z;
                r1 = SPL;
                writeback = 1;
                rd_idu = WZ;
            end
            S3: begin
                next = S4;
                addrh = W;
                addrl = Z;
                r1 = SPH;
                writeback = 1;
            end
            S4: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b00_xx1_001: begin
            `executing("add hl, r16")
            data_sel = ALU;
            flag_mask = NFLAG | HFLAG | CFLAG ;
            case ( state )
            S0: begin
                next = S1;
                alu_op = ADD;
                r1 = L;
                r2 = LSB[IR[5:4]];
                rd = L;
            end
            S1: begin
                alu_op = ADC;
                r1 = H;
                r2 = MSB[IR[5:4]];
                rd = H;

                addrh = PCH;
                addrl = PCL;
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b00_xx1_010: begin
            $display("ld a, [r16mem]");
            case ( state )
            S0: begin
                next = S1;
                addrh = MSBm[IR[5:4]];
                addrl = LSBm[IR[5:4]];
                data_sel = DIN;
                idu_op = r16mem_op[IR[5:4]];
                rd_idu = r16mem_rd[IR[5:4]];
                rd = A;
            end
            S1: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b00_xx1_011: begin
            $display("dec r16");
            case ( state )
            S0: begin
                next = S1;
                addrh = MSB[IR[5:4]];
                addrl = LSB[IR[5:4]];
                rd_idu = IR[5:4];
                idu_op = DEC;
            end
            S1: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b00_010_000: begin
            `executing("stop")
            // temporary (possibly incorrect) implementation of stop
            case ( state )
                S0: begin
                    if ( wake ) begin
                        rd_idu = PC;
                        fetch = 1;
                    end else begin
                        next = S1;
                    end
                end
                S1: $finish();
            endcase
        end
        'b00_011_000: begin
            `executing("jr imm8")
            case ( state )
            S0: begin
                next = S1;
                data_sel = DIN;
                rd = Z;
                rd_idu = PC;
            end
            S1: begin
                next = S2;
                data_sel = ALU;
                alu_op = ADD;
                r1 = PCL;
                r2 = Z;
                rd = Z;
                idu_op = ADJ;
                addrl = PCH;
                addrh = CTR;
                ctr = 8'b0;
            end
            S2: begin
                addrh = W;
                addrl = Z;
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b00_1xx_000: begin
            `executing("jr cond, imm8")
            case ( state )
            S0: begin
                data_sel = DIN;
                rd = Z;
                rd_idu = PC;
                cc = IR[4:3];
                if ( cc_true ) begin
                    next = S2;
                end else begin
                    next = S1;
                end
            end
            S1: begin
                rd_idu = PC;
                fetch = 1;
            end
            S2: begin
                next = S3;
                data_sel = ALU;
                alu_op = ADD;
                r1 = PCL;
                r2 = Z;
                rd = Z;
                idu_op = ADJ;
                addrl = PCH;
                addrh = CTR;
                ctr = 8'b0;
            end
            S3: begin
                addrh = W;
                addrl = Z;
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b01_xxx_xxx: begin
            case ( state )
            S0: begin
                if ( halt ) begin
                    next = S1;
                    idu_op = DEC;
                    rd_idu = PC;
                end
                else if ( IR[5:3] == 'b110 ) begin
                    next = S2;
                    addrh = H;
                    addrl = L;
                    r1 = IR[2:0];
                    writeback = 1;
                end 
                else if ( IR[2:0] == 'b110 ) begin
                    next = S2;
                    addrh = H;
                    addrl = L;
                    data_sel = DIN;
                    rd = IR[5:3];
                end
                else begin
                    fetch = 1;
                    rd_idu = PC;
                    r1 = IR[2:0];
                    rd = IR[5:3];
                    data_sel = ALU;
                end
            end
            S1: begin
                fetch = 1;
                next = S1;
                if ( wake ) begin
                    next = S0;
                    rd_idu = PC;
                end
            end
            S2: begin
                fetch = 1;
                rd_idu = PC;
            end
            endcase
        end
        'b10_xxx_xxx: begin
            case ( state )
            S0: begin
                if ( IR[2:0] == 'b110 ) begin
                    next = S1;
                    rd = Z;
                    addrh = H;
                    addrl = L;
                    data_sel = DIN;
                end else begin
                    r1 = A;
                    r2 = IR[2:0];
                    data_sel = ALU; 
                    if ( IR[5:3] == 'b111 ) begin
                        alu_op = SUB;
                    end else begin
                        alu_op = {2'b00, IR[5:3]};
                        rd = A; 
                    end
                    flag_mask = ALLFLAG;
                    rd_idu = PC;
                    fetch = 1;
                end
            end
            S1: begin
                r1 = A;
                r2 = Z;
                data_sel = ALU;
                if ( IR[5:3] == 'b111 ) begin
                    alu_op = SUB;
                end else begin
                    alu_op = {2'b00, IR[5:3]};
                    rd = A; 
                end
                flag_mask = ALLFLAG;
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        endcase

    end


endmodule
