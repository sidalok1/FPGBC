
module ControlUnit(
        clk,
        IE, IF,
        ack_IF,
        data,
        r1,
        r2,
        rd,
        ctr,
        data_sel,
        addrh, addrl,
        rd_idu,
        read,
        write,
        alu_op, flag_mask, idu_op,
        cc, cc_true,
        intr_req
);
    
    `include "RegFile_params.vh"
    `include "Control_params.vh"
    `include "IDU_params.vh"
    `include "ALU_params.vh"

    input wire          clk;
    input wire          intr_req;
    input wire  [7:0]   data, IE, IF;
    output reg          write = 0;
    output wire         read;
    output reg          data_sel = DIN;
    output reg  [3:0]   r1 = CTR, r2 = CTR, rd = CTR, addrh = PCH, addrl = PCL;
    output reg  [7:0]   ctr;
    output reg  [2:0]   rd_idu = FF;
    output reg  [ALU_OPWIDTH:0]   alu_op;
    output reg  [IDU_OPWIDTH:0]   idu_op;
    output reg  [4:0]   flag_mask;
    output reg  [1:0]   cc;
    output reg  [7:0]   ack_IF = 0;
    input wire          cc_true;

    reg [7:0] IR;
    reg fetch = 1;
    reg read_from_mem = 0;
    assign read = fetch | read_from_mem;
    
    reg [4:0] state = S0, next = S0;
    reg prefix = 0, prefix_next = 0;

    reg IME;
    reg set_IME = 0, set_IME_next = 0, unset_IME = 0;

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

    wire [3:0] MSB [0:3], LSB [0:3];
    assign MSB[BC] = B;
    assign LSB[BC] = C;
    assign MSB[DE] = D;
    assign LSB[DE] = E;
    assign MSB[HL] = H;
    assign LSB[HL] = L;
    assign MSB[SP] = SPH;
    assign LSB[SP] = SPL;

    wire [3:0] MSBm [0:3], LSBm [0:3];
    assign MSBm[0] = B;
    assign LSBm[0] = C;
    assign MSBm[1] = D;
    assign LSBm[1] = E;
    assign MSBm[2] = H;
    assign LSBm[2] = L;
    assign MSBm[3] = H;
    assign LSBm[3] = L;

    wire [3:0] MSBs [0:3], LSBs [0:3];
    assign MSBs[BC] = B;
    assign LSBs[BC] = C;
    assign MSBs[DE] = D;
    assign LSBs[DE] = E;
    assign MSBs[HL] = H;
    assign LSBs[HL] = L;
    assign MSBs[SP] = A;
    assign LSBs[SP] = F;


    wire halt;
    assign halt = IR[5:0] == 6'b110_110;

    always @ ( posedge clk ) begin
        state <= next;
        if ( fetch ) begin
            IR <= data;
        end
        if ( set_IME ) begin
            set_IME_next <= 1;
        end else begin
            set_IME_next <= 0;
        end
        if ( unset_IME ) begin
            IME <= 0;
        end else if ( set_IME_next ) begin
            IME <= 1;
        end else begin
            IME <= IME;
        end
        prefix <= prefix_next;
    end

    always @* begin
        next = S0;
        fetch = 0;
        write = 0;
        read_from_mem = 0;
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
        set_IME = 0;
        unset_IME = 0;
        prefix_next = 0;

        

        // begin state logic
        if ( prefix ) begin 
            // prefixed arithmetic
            prefix_next = 1;
            case ( state )
            S0: begin
                if ( IR[2:0] == 'b110 ) begin
                    next = S1;
                    addrh = H;
                    addrl = L;
                    rd = Z;
                    data_sel = DIN;
                    read_from_mem = 1;
                end else begin
                    rd = (IR[7:6] == 2'b01) ? CTR : IR[2:0]; // no rd for BIT
                    r1 = IR[2:0];
                    r2 = CTR;
                    ctr = {5'b0, IR[5:3]};
                    alu_op = {2'b10, IR[7:6]};
                    flag_mask = ALLFLAG;
                    rd_idu = PC;
                    fetch = 1;
                    prefix_next = 0;
                end
            end
            S1: begin
                addrh = H;
                addrl = L;
                r1 = Z;
                r2 = CTR;
                ctr = {5'b0, IR[5:3]};
                alu_op = {2'b10, IR[7:6]};
                flag_mask = ALLFLAG;
                write = IR[7:6] != 2'b01; // no write for BIT
                next = S2;
            end
            S2: begin
                rd_idu = PC;
                fetch = 1;
                prefix_next = 0;
            end
            endcase
        end
        else casex ( IR )
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
                data_sel = DIN;
                read_from_mem = 1;
            end
            S1: begin
                next = S2;
                rd_idu = PC;
                rd = MSB[IR[5:4]];
                data_sel = DIN;
                read_from_mem = 1;
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
                write = 1;
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
                    data_sel = DIN;
                    read_from_mem = 1;
                end else begin
                    rd_idu = PC;
                    fetch = 1;
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
                write = 1;
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
                    data_sel = DIN;
                    read_from_mem = 1;
                end else begin
                    rd_idu = PC;
                    fetch = 1;
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
                write = 1;
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
                data_sel = DIN;
                read_from_mem = 1;
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
                write = 1;
            end
            S2: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b00_xxx_111: begin
            r1 = A;
            data_sel = ALU;
            rd_idu = PC;
            fetch = 1;
            flag_mask = ALLFLAG;
            casex ( IR[5:3] )
            'b0xx: begin
                rd = A;
                r2 = CTR;
                ctr =  {4'b0, 
                        1'b1, // indicates to ALU op1 is A (carry flag reset)
                        IR[5:3]};
                alu_op = SHR;
            end
            'b100: begin
                rd = A;
                alu_op = DAA;
            end
            'b101: begin
                rd = A;
                alu_op = CPL;
            end
            'b110: begin
                alu_op = SCF;
            end
            'b111: begin
                alu_op = CCF;
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
                read_from_mem = 1;
                rd_idu = PC;
            end
            S1: begin
                next = S2;
                rd = W;
                data_sel = DIN;
                read_from_mem = 1;
                rd_idu = PC;
            end
            S2: begin
                next = S3;
                addrh = W;
                addrl = Z;
                r1 = SPL;
                write = 1;
                rd_idu = WZ;
            end
            S3: begin
                next = S4;
                addrh = W;
                addrl = Z;
                r1 = SPH;
                write = 1;
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
                read_from_mem = 1;
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
                    if ( IE & IF ) begin
                        rd_idu = PC;
                        fetch = 1;
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
                read_from_mem = 1;
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
                read_from_mem = 1;
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
                    write = 1;
                end 
                else if ( IR[2:0] == 'b110 ) begin
                    next = S2;
                    addrh = H;
                    addrl = L;
                    data_sel = DIN;
                    read_from_mem = 1;
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
                if ( IE & IF ) begin
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
                    read_from_mem = 1;
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
        'b11_0xx_000: begin
            `executing("ret cc")
            case ( state )
            S0: begin
                cc = IR[4:3];
                if ( cc_true ) begin
                    next = S1;
                end else begin
                    next = S4;
                end
            end
            S1: begin
                addrh = SPH;
                addrl = SPL;
                rd_idu = SP;
                data_sel = DIN;
                read_from_mem = 1;
                rd = Z;
                next = S1;
            end
            S2: begin
                addrh = SPH;
                addrl = SPL;
                rd_idu = SP;
                data_sel = DIN;
                read_from_mem = 1;
                rd = W;
                next = S2;
            end
            S3: begin
                addrh = W;
                addrl = Z;
                idu_op = ZER;
                rd_idu = PC;
                next = S3;
            end
            S4: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b11_0x1_001: begin
            if ( IR[4] )    `executing("reti")
            else            `executing("ret")
            case ( state )
            S0: begin
                addrh = SPH;
                addrl = SPL;
                rd_idu = SP;
                data_sel = DIN;
                read_from_mem = 1;
                rd = Z;
                next = S1;
            end
            S1: begin
                addrh = SPH;
                addrl = SPL;
                rd_idu = SP;
                data_sel = DIN;
                read_from_mem = 1;
                rd = W;
                next = S2;
            end
            S2: begin
                addrh = W;
                addrl = Z;
                idu_op = ZER;
                rd_idu = PC;
                set_IME = IR[4];
                next = S3;
            end
            S3: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b11_xx0_001: begin
            `executing("pop r16stk")
            case ( state )
            S0: begin
                addrh = SPH;
                addrl = SPL;
                rd = LSBs[IR[5:4]];
                data_sel = DIN;
                read_from_mem = 1;
                rd_idu = SP;
                next = S1;
            end
            S1: begin
                addrh = SPH;
                addrl = SPL;
                rd = MSBs[IR[5:4]];
                data_sel = DIN;
                read_from_mem = 1;
                rd_idu = SP;
                next = S2;
            end
            S2: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b11_101_001: begin
            `executing("jp hl")
            case ( state )
            S0: begin
                addrh = H;
                addrl = L;
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b11_0xx_010: begin
            `executing("jp cond, imm16")
            case ( state )
            S0: begin
                data_sel = DIN;
                read_from_mem = 1;
                rd = Z;
                rd_idu = PC;
                next = S1;
            end
            S1: begin
                data_sel = DIN;
                read_from_mem = 1;
                rd = W;
                rd_idu = PC;
                cc = IR[4:3];
                if ( cc_true ) begin
                    next = S2;
                end else begin
                    next = S3;
                end
            end
            S2: begin
                addrh = W;
                addrl = Z;
                idu_op = ZER;
                rd_idu = PC;
                next = S3;
            end
            S3: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b11_000_011: begin
            `executing("jp, imm16")
            case ( state )
                S0: begin
                data_sel = DIN;
                read_from_mem = 1;
                rd = Z;
                rd_idu = PC;
                next = S1;
            end
            S1: begin
                data_sel = DIN;
                read_from_mem = 1;
                rd = W;
                rd_idu = PC;
                next = S2;
            end
            S2: begin
                addrh = W;
                addrl = Z;
                idu_op = ZER;
                rd_idu = PC;
                next = S3;
            end
            S3: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b11_0xx_100: begin
            `executing("call cond, imm16")
            case ( state )
            S0: begin
                data_sel = DIN;
                read_from_mem = 1;
                rd = Z;
                rd_idu = PC;
                next = S1;
            end
            S1: begin
                data_sel = DIN;
                read_from_mem = 1;
                // some wonky logic to avoid extra state
                // might need to change later
                cc = IR[4:3];
                if ( cc_true ) begin 
                    rd = W;
                    rd_idu = PC;
                    next = S2;
                end else begin
                    rd_idu = WZ;
                    next = S5;
                end
            end
            S2: begin
                addrh = SPH;
                addrl = SPL;
                idu_op = DEC;
                rd_idu = SP;
                next = S3;
            end
            S3: begin
                addrh = SPH;
                addrl = SPL;
                r1 = PCH;
                write = 1;
                idu_op = DEC;
                rd_idu = SP;
                next = S4;
            end
            S4: begin
                addrh = SPH;
                addrl = SPL;
                r1 = PCL;
                write = 1;
                next = S5;
            end
            S5: begin
                addrh = W;
                addrl = Z;
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b11_001_101: begin
            `executing("call imm16")
            case ( state )
                S0: begin
                data_sel = DIN;
                read_from_mem = 1;
                rd = Z;
                rd_idu = PC;
                next = S1;
            end
            S1: begin
                data_sel = DIN;
                read_from_mem = 1;
                rd = W;
                rd_idu = PC;
                next = S2;
            end
            S2: begin
                addrh = SPH;
                addrl = SPL;
                idu_op = DEC;
                rd_idu = SP;
                next = S3;
            end
            S3: begin
                addrh = SPH;
                addrl = SPL;
                r1 = PCH;
                write = 1;
                idu_op = DEC;
                rd_idu = SP;
                next = S4;
            end
            S4: begin
                addrh = SPH;
                addrl = SPL;
                r1 = PCL;
                write = 1;
                next = S5;
            end
            S5: begin
                addrh = W;
                addrl = Z;
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b11_xx0_101: begin
            `executing("push r16stk")
            case ( state )
            S0: begin
                addrh = SPH;
                addrl = SPL;
                idu_op = DEC;
                rd_idu = SP;
                next = S1;
            end
            S1: begin
                addrh = SPH;
                addrl = SPL;
                idu_op = DEC;
                rd_idu = SP;
                r1 = MSBs[IR[5:4]];
                write = 1;
                next = S2;
            end
            S2: begin
                addrh = SPH;
                addrl = SPL;
                r1 = LSBs[IR[5:4]];
                write = 1;
                next = S3;
            end
            S3: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b11_xxx_110: begin
            // A, imm8 arithmetic
            case ( state )
            S0: begin
                data_sel = DIN;
                read_from_mem = 1;
                next = S1;
                rd = Z;
                rd_idu = PC;
            end
            S1: begin
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
            endcase
        end
        'b11_100_000: begin
            `executing("ldh [imm8], a")
            case ( state )
            S0: begin
                data_sel = DIN;
                read_from_mem = 1;
                rd = Z;
                rd_idu = PC;
                next = S1;
            end
            S1: begin
                addrh = CTR;
                ctr = 8'hFF;
                addrl = Z;
                r1 = A;
                write = 1;
                next = S2;
            end
            S2: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b11_110_000: begin
            `executing("ldh a, [imm8]")
            case ( state )
            S0: begin
                data_sel = DIN;
                read_from_mem = 1;
                rd = Z;
                rd_idu = PC;
                next = S1;
            end
            S1: begin
                addrh = CTR;
                ctr = 8'hFF;
                data_sel = DIN;
                read_from_mem = 1;
                rd = A;
                next = S2;
            end
            S2: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b11_100_010: begin
            `executing("ldh [c], a")
            case ( state )
            S0: begin
                addrh = CTR;
                ctr = 8'hFF;
                addrl = C;
                r1 = A;
                write = 1;
                next = S1;
            end
            S1: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b11_110_010: begin
            `executing("ldh a, [c]")
            case ( state )
            S0: begin
                addrh = CTR;
                ctr = 8'hFF;
                addrl = C;
                rd = A;
                data_sel = DIN;
                read_from_mem = 1;
                next = S1;
            end
            S1: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b11_101_010: begin
            `executing("ld [imm16], a")
            case ( state )
            S0: begin
                data_sel = DIN;
                read_from_mem = 1;
                rd = Z;
                rd_idu = PC;
                next = S1;
            end
            S1: begin
                data_sel = DIN;
                read_from_mem = 1;
                rd = W;
                rd_idu = PC;
                next = S2;
            end
            S2: begin
                addrh = W;
                addrl = Z;
                r1 = A;
                write = 1;
                next = S3;
            end
            S3: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b11_111_010: begin
            `executing("ld, a, [imm16]")
            case ( state )
            S0: begin
                data_sel = DIN;
                read_from_mem = 1;
                rd = Z;
                rd_idu = PC;
                next = S1;
            end
            S1: begin
                data_sel = DIN;
                read_from_mem = 1;
                rd = W;
                rd_idu = PC;
                next = S2;
            end
            S2: begin
                addrh = W;
                addrl = Z;
                data_sel = DIN;
                read_from_mem = 1;
                rd = A;
                next = S3;
            end
            S3: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b11_101_000: begin
            `executing("add sp, imm8")
            case ( state )
            S0: begin
                data_sel = DIN;
                read_from_mem = 1;
                rd = Z;
                rd_idu = PC;
                next = S1;
            end
            S1: begin
                data_sel = ALU;
                alu_op = ADD;
                rd = SPL;
                r1 = SPL;
                r2 = Z;
                next = S2;
            end
            S2: begin
                data_sel = ALU;
                alu_op = ADC;
                rd = SPH;
                r1 = SPH;
                r2 = CTR;
                ctr = 8'h00;
                next = S3;
            end
            S3: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b11_111_000: begin
            `executing("ld hl, dp + imm8")
            case ( state )
            S0: begin
                data_sel = DIN;
                read_from_mem = 1;
                rd = Z;
                rd_idu = PC;
                next = S1;
            end
            S1: begin
                data_sel = ALU;
                alu_op = ADD;
                rd = L;
                r1 = SPL;
                r2 = Z;
            end
            S2: begin
                data_sel = ALU;
                alu_op = ADC;
                rd = H;
                r1 = SPH;
                r2 = CTR;
                ctr = 8'h00;
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b11_111_001: begin
            `executing("ld sp, hl")
            case ( state )
            S0: begin
                addrh = H;
                addrl = L;
                idu_op = ZER;
                rd_idu = SP;
                next = S1;
            end
            S1: begin
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b11_110_011: begin
            `executing("di")
            case ( state )
            S0: begin
                unset_IME = 1;
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b11_111_011: begin
            `executing("ei")
            case ( state )
            S0: begin
                set_IME = 1;
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'b11_xxx_111: begin
            `executing("rst tgt3")
            case ( state )
            S0: begin
                addrh = SPH;
                addrl = SPL;
                idu_op = DEC;
                rd_idu = SP;
                r1 = CTR;
                ctr = {2'b00, IR[5:3], 3'b000};
                rd = Z;
                data_sel = ALU;
                next = S1;
            end
            S1: begin
                addrh = SPH;
                addrl = SPL;
                idu_op = DEC;
                rd_idu = SP;
                r1 = PCH;
                write = 1;
                next = S2;
            end
            S2: begin
                addrh = SPH;
                addrl = SPL;
                r1 = PCL;
                write = 1;
                next = S3;
            end
            S3: begin
                addrh = CTR;
                ctr = 8'b0;
                addrl = Z;
                rd_idu = PC;
                fetch = 1;
            end
            endcase
        end
        'hCB: begin
            $display("prefix");
            prefix_next = 1;
            rd_idu = PC;
            fetch = 1;
        end
        endcase
    end


endmodule
