`default_nettype none
module ControlUnit(
        clk, rst, en,
        IE, IF, KEY1,
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
        alu_op, flag_mask, idu_op, load_flags, clear_flags,
        cc, cc_true,
        wake,
        stop,
        halt
);
    
    `include "RegFile_params.vh"
    `include "Control_params.vh"
    `include "IDU_params.vh"
    `include "ALU_params.vh"

    input wire          clk;
    input wire          en;
    input wire          rst;
    input wire          wake;
    output reg          stop = 0, halt = 0;
    input wire  [7:0]   data, IE, IF, KEY1;
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
    output reg load_flags;
    output reg [3:0] clear_flags;

    reg [7:0] IR;
    reg fetch = 1;
    reg read_from_mem = 0;
    assign read = fetch | read_from_mem;
    
    reg [5:0] state = S0, next = S0;
    reg [5:0] intr_state = S0, intr_state_n, intr_return_state = S0, intr_return_state_n;
    reg prefix = 0, prefix_next = 0, prefix_return = 0, prefix_return_n;

    reg IME;
    reg set_IME = 0, set_IME_next = 0, unset_IME;

    wire [2:0] next_interrupt;
    wire intr_valid;
    // PriorityEncoder #(
    //     .WIDTH(5)
    // ) intr_priority_encoder (
    //     .i( IE[4:0] & IF[4:0] ),
    //     .o( next_interrupt ),
    //     .v( intr_valid )
    // );
    PriorityEncoder5 intr_priority_encoder (
        .i( IE[4:0] & IF[4:0] ),
        .o( next_interrupt ),
        .v( intr_valid )
    );
    wire [15:0] interrupt_jump_vector [0:4];
    assign interrupt_jump_vector[0] = 16'h40; // VBlank interrupt
    assign interrupt_jump_vector[1] = 16'h48; // STAT interrupt
    assign interrupt_jump_vector[2] = 16'h50; // Timer interrupt
    assign interrupt_jump_vector[3] = 16'h58; // Serial interrupt
    assign interrupt_jump_vector[4] = 16'h60; // Joypad interrupt

    wire SPEED_SWITCH_ARMED = KEY1[0];

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


    wire halt_condition;
    assign halt_condition = IR[5:0] == 6'b110_110;

    // integer i = 0, j = 0;
    // always @( posedge clk ) if ( rst ) begin
    //     j <= 0;
    //     i <= 0;
    // end 
    // else begin
    //     $display("Sys-cycle: %d", j);
    //     j <= j + 1;
    //     if ( en ) begin
    //         $display("M-cycle: %d", i);
    //         i <= i + 1;
    //     end
    // end

    always @ ( posedge clk ) begin
        if ( rst ) begin
            state <= S0;
            intr_state <= S0;
            intr_return_state <= 0;
            IR <= 0;
            set_IME_next <= 0;
            IME <= 0;
            prefix <= 0;
            prefix_return <= 0;
        end
        else if ( en ) begin
            state <= next;
            intr_state <= intr_state_n;
            intr_return_state <= intr_return_state_n;
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
            prefix_return <= prefix_return_n;
        end
    end

    always @* begin
        next = S0;
        intr_state_n = S0;
        intr_return_state_n = intr_return_state;
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
        prefix_return_n = prefix_return;
        ack_IF = 0;
        stop = 0;
        halt = 0;
        load_flags = 0;
        clear_flags = 4'b0;
        

        // begin state logic
        if ( IME & intr_valid ) begin
            case ( intr_state ) 
            S0: begin
                // save current state, to return to on reti
                intr_return_state_n = state;
                prefix_return_n = prefix;
                addrh = SPH;
                addrl = SPL;
                idu_op = DEC;
                rd_idu = SP;
                intr_state_n = S1;
            end
            S1: begin
                addrh = SPH;
                addrl = SPL;
                r1 = PCH;
                write = 1;
                idu_op = DEC;
                rd_idu = SP;
                intr_state_n = S2;
            end
            S2: begin
                addrh = SPH;
                addrl = SPL;
                r1 = PCL;
                write = 1;
                intr_state_n = S3;
            end
            S3: begin
                data_sel = ALU;
                ctr = interrupt_jump_vector[next_interrupt][7:0];
                rd = PCL;
                intr_state_n = S4;
            end
            S4: begin
                data_sel = ALU;
                ctr = interrupt_jump_vector[next_interrupt][15:8];
                rd = PCH;
                intr_state_n = S5;
            end
            S5: begin
                rd_idu = PC;
                idu_op = ZER;
                ack_IF[next_interrupt] = 1;
                unset_IME = 1;
                fetch = 1;
            end
            default:; // one-hot
            endcase
        end
        else if ( prefix ) begin 
            // prefixed arithmetic
            prefix_next = 1;
            case ( state )
            S0: begin
                if ( IR[2:0] == 'b110 ) begin // OP xxx, [hl]
                    next = S1;
                    addrh = H;
                    addrl = L;
                    rd = Z;
                    data_sel = DIN;
                    read_from_mem = 1;
                end else begin
                    rd = (IR[7:6] == 2'b01) ? CTR : {1'b0, IR[2:0]}; // no rd for BIT
                    r1 = {1'b0, IR[2:0]};
                    r2 = CTR;
                    ctr = {5'b0, IR[5:3]};
                    alu_op = {2'b10, IR[7:6]};
                    data_sel = ALU;
                    flag_mask = ALLFLAG;
                    rd_idu = PC;
                    fetch = 1;
                    prefix_next = 0;
                end
            end
            S1: begin
                if ( IR[7:6] == 2'b01 ) begin // BIT u3, [hl]
                    rd_idu = PC;
                    fetch = 1;
                    prefix_next = 0;
                end
                else begin
                    addrh = H;
                    addrl = L;
                    write = 1;
                    next = S2;
                end
                r1 = Z;
                r2 = CTR;
                ctr = {5'b0, IR[5:3]};
                alu_op = {2'b10, IR[7:6]};
                flag_mask = ALLFLAG;
            end
            S2: begin
                rd_idu = PC;
                fetch = 1;
                prefix_next = 0;
            end
            default:; // one-hot
            endcase
        end
        else casez ( IR )
        'b00_000_000: begin
            `ifdef DEBUG
                if ( en )
                $display("nop");
            `endif
            // nop
            rd_idu = PC;
            fetch = 1;
        end
        'b00_??0_001: begin
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
            default:; // one-hot
            endcase
        end
        'b00_??0_010: begin
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
            default:; // one-hot
            endcase
        end
        'b00_??0_011: begin
            `ifdef DEBUG
                if ( en )
                $display("inc r16");
            `endif
            // 
            case ( state )
            S0: begin
                next = S1;
                addrh = MSB[IR[5:4]];
                addrl = LSB[IR[5:4]];
                rd_idu = {1'b0, IR[5:4]};
            end
            S1: begin
                rd_idu = PC;
                fetch = 1;
            end
            default:; // one-hot
            endcase
        end
        'b00_???_100: begin
            `ifdef DEBUG
                if ( en )
                $display("inc r8");
            `endif
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
                    rd = {1'b0, IR[5:3]};
                    r1 = {1'b0, IR[5:3]};
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
            default:; // one-hot
            endcase
        end
        'b00_???_101: begin
            `ifdef DEBUG
                if ( en )
                $display("dec r8");
            `endif
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
                    rd = {1'b0, IR[5:3]};
                    r1 = {1'b0, IR[5:3]};
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
            default:; // one-hot
            endcase
        end
        'b00_???_110: begin
            `ifdef DEBUG
                if ( en )
                $display("ld r8, imm8");
            `endif
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
                    rd = {1'b0, IR[5:3]};
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
            default:; // one-hot
            endcase
        end
        'b00_???_111: begin
            r1 = A;
            data_sel = ALU;
            rd_idu = PC;
            fetch = 1;
            flag_mask = ALLFLAG;
            casez ( IR[5:3] )
            'b0??: begin
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
            default:; // one-hot
            endcase
        end
        'b00_??1_001: begin
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
            default:; // one-hot
            endcase
        end
        'b00_??1_010: begin
            `ifdef DEBUG
                if ( en )
                $display("ld a, [r16mem]");
            `endif
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
            default:; // one-hot
            endcase
        end
        'b00_??1_011: begin
            `ifdef DEBUG
                if ( en )
                $display("dec r16");
            `endif
            case ( state )
            S0: begin
                next = S1;
                addrh = MSB[IR[5:4]];
                addrl = LSB[IR[5:4]];
                rd_idu = {1'b0, IR[5:4]};
                idu_op = DEC;
            end
            S1: begin
                rd_idu = PC;
                fetch = 1;
            end
            default:; // one-hot
            endcase
        end
        'b00_010_000: begin
            `executing("stop")
            // temporary (possibly incorrect) implementation of stop
            case ( state )
                S0: begin
                    stop = 1;
                    if ( IME == 0 && SPEED_SWITCH_ARMED == 0 ) $finish;
                    // if ( IE & IF ) begin
                    //     rd_idu = PC;
                    //     fetch = 1;
                    // end 
                end
            default:; // one-hot
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
                addrh = PCH;
                addrl = CTR;
                rd_idu = W_;
                ctr = 8'b0;
            end
            S2: begin
                addrh = W;
                addrl = Z;
                rd_idu = PC;
                fetch = 1;
            end
            default:; // one-hot
            endcase
        end
        'b00_1??_000: begin
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
                addrh = PCH;
                addrl = CTR;
                rd_idu = W_;
                ctr = 8'b0;
            end
            S3: begin
                addrh = W;
                addrl = Z;
                rd_idu = PC;
                fetch = 1;
            end
            default:; // one-hot
            endcase
        end
        'b01_???_???: begin
            case ( state )
            S0: begin
                if ( halt_condition ) begin
                    next = S1;
                    // rd_idu = PC;
                end
                else if ( IR[5:3] == 'b110 ) begin
                    next = S2;
                    addrh = H;
                    addrl = L;
                    r1 = {1'b0, IR[2:0]};
                    write = 1;
                end 
                else if ( IR[2:0] == 'b110 ) begin
                    next = S2;
                    addrh = H;
                    addrl = L;
                    data_sel = DIN;
                    read_from_mem = 1;
                    rd = {1'b0, IR[5:3]};
                end
                else begin
                    fetch = 1;
                    rd_idu = PC;
                    r1 = {1'b0, IR[2:0]};
                    rd = {1'b0, IR[5:3]};
                    data_sel = ALU;
                end
            end
            S1: begin
                // Nintendo says that awaking from an interrupt can still happen
                // with IME = 0, just moves on to next instruction
                halt = 1;
                next = S1;
                if ( |IF[4:0] ) begin
                    next = S0;
                    fetch = 1;
                end
            end
            S2: begin
                fetch = 1;
                rd_idu = PC;
            end
            default:; // one-hot
            endcase
        end
        'b10_???_???: begin
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
                    r2 = {1'b0, IR[2:0]};
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
            default:; // one-hot
            endcase
        end
        'b11_0??_000: begin
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
                next = S2;
            end
            S2: begin
                addrh = SPH;
                addrl = SPL;
                rd_idu = SP;
                data_sel = DIN;
                read_from_mem = 1;
                rd = W;
                next = S3;
            end
            S3: begin
                addrh = W;
                addrl = Z;
                idu_op = ZER;
                rd_idu = PC;
                next = S4;
            end
            S4: begin
                rd_idu = PC;
                fetch = 1;
            end
            default:; // one-hot
            endcase
        end
        'b11_0?1_001: begin
            if ( IR[4] ) begin
                //
                `executing("reti")
            end
            else begin
                //            
                `executing("ret")
            end
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
                if ( IR[4] ) begin // if returning from interrupt, go to previous state
                    // next = intr_return_state;
                    next = S0;
                    prefix_next = prefix_return;
                end 
                else begin
                    next = S0;
                    prefix_next = 0;
                end
                rd_idu = PC;
                fetch = 1;
            end
            default:; // one-hot
            endcase
        end
        'b11_??0_001: begin
            `executing("pop r16stk")
            case ( state )
            S0: begin
                addrh = SPH;
                addrl = SPL;
                if ( IR[5:4] == 2'b11 ) // pop AF
                    load_flags = 1;
                else
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
            default:; // one-hot
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
            default:; // one-hot
            endcase
        end
        'b11_0??_010: begin
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
            default:; // one-hot
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
            default:; // one-hot
            endcase
        end
        'b11_0??_100: begin
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
            default:; // one-hot
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
            default:; // one-hot
            endcase
        end
        'b11_??0_101: begin
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
            default:; // one-hot
            endcase
        end
        'b11_???_110: begin
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
                r2 = Z;
                data_sel = ALU; 
                if ( IR[5:3] == 'b111 ) begin // compare ( discard result )
                    alu_op = SUB;
                end else begin
                    rd = A; 
                    alu_op = {2'b00, IR[5:3]};
                end
                flag_mask = ALLFLAG;
                rd_idu = PC;
                fetch = 1;
            end
            default:; // one-hot
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
            default:; // one-hot
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
                addrl = Z;
                data_sel = DIN;
                read_from_mem = 1;
                rd = A;
                next = S2;
            end
            S2: begin
                rd_idu = PC;
                fetch = 1;
            end
            default:; // one-hot
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
            default:; // one-hot
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
            default:; // one-hot
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
            default:; // one-hot
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
            default:; // one-hot
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
                flag_mask = ALLFLAG;
                next = S2;
            end
            S2: begin
                // data_sel = ALU;
                // alu_op = ADC;
                // rd = SPH;
                // r1 = SPH;
                // r2 = CTR;
                r2 = Z; // so IDU knows if operand was signed
                idu_op = ADJ;
                addrh = SPH;
                addrl = SPL;
                rd_idu = SP;
                clear_flags = ZFLAG[3:0] | NFLAG[3:0];
                ctr = 8'h00;
                next = S3;
            end
            S3: begin
                rd_idu = PC;
                fetch = 1;
            end
            default:; // one-hot
            endcase
        end
        'b11_111_000: begin
            `executing("ld hl, sp + imm8")
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
                flag_mask = HFLAG | CFLAG;
                alu_op = ADD;
                rd = L;
                r1 = SPL;
                r2 = Z;
                idu_op = ADJ;
                addrh = SPH;
                addrl = SPL;
                rd_idu = WZ;
                next = S2;
            end
            S2: begin
                data_sel = ALU;
                clear_flags = ZFLAG[3:0] | NFLAG[3:0];
                alu_op = PAS;
                rd = H;
                r1 = W;
                rd_idu = PC;
                fetch = 1;
            end
            default:; // one-hot
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
            default:; // one-hot
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
            default:; // one-hot
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
            default:; // one-hot
            endcase
        end
        'b11_???_111: begin
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
            default:; // one-hot
            endcase
        end
        'hCB: begin
            `ifdef DEBUG
                if ( en )
                $display("prefix");
            `endif
            prefix_next = 1;
            rd_idu = PC;
            fetch = 1;
        end
        endcase
    end

    

endmodule