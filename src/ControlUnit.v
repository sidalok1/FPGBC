`include "Control_headers.vh"
`include "ALU_headers.vh"
`include "IDU_headers.vh"
`include "RegFile_headers.vh"

module ControlUnit(
        clk, 
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
        intr_req
    );
    input wire          clk;
    input wire          intr_req;
    input wire  [7:0]   IR;
    output reg          writeback = 0;
    output reg          data_sel = `din;
    output reg  [3:0]   r1 = `ctr, r2 = `ctr, rd = `ctr, addrh = `pch, addrl = `pcl;
    output reg  [7:0]   ctr;
    output reg  [2:0]   rd_idu = `ff;
    output reg  [`ALU_opwidth:0]   alu_op;
    output reg  [`IDU_opwidth:0]   idu_op;
    output reg  [3:0]   flag_mask;
    output reg          fetch = 1;
    
    reg [5:0] state = `s0, next = `s0;
    reg prefix = 0;

    reg [7:0] IE = 0;
    reg IME;

    always @ ( posedge clk ) begin
        state <= next;
    end

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
        flag_mask = 0;
        data_sel = `din;
        // begin state logic
        case ( prefix )
        0: begin
            case ( IR[7:6] ) 
            'b00: begin
                case ( IR[2:0] )
                'b000: begin
                    casex ( IR[5:3] )
                    'b000: begin
                        $display("nop");
                        // nop
                        rd_idu = `pc;
                        fetch = 1;
                    end
                    'b001: begin
                        // ld [imm16], sp
                        $display("ld [imm16], sp\t-\tstate: %5b", state);
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
                        default:;
                        endcase
                    end
                    'b010:;// TODO: stop
                    'b011: begin
                        $display("jr imm8");
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
                        default:;
                        endcase
                    end
                    endcase
                end
                default: $display("invalid block1");
                endcase
            end
            default: $display("invalid instruction: %h", IR);
            endcase
        end
        1:;
        endcase
    end


endmodule
