`include "ALU_headers.vh"
`include "RegFile_headers.vh"

module ALU ( op, in1, in2, out, carry_in, flags_out );
    input [`ALU_opwidth:0] op;
    input [7:0] in1, in2;
    input carry_in;
    output wire [7:0] out;
    output wire [3:0] flags_out;
    
    reg z = 0, n = 0, c = 0, h = 0;
    assign flags_out = {z, n, h, c};

    reg [8:0] full_result = 0;
    reg [4:0] half_result = 0;

    assign out = full_result[7:0];

    always @( op, in1, in2, carry_in ) begin
        case (op) 
        `PAS: full_result[7:0] <= in1;
        `ADD: begin
            full_result = in1 + in2;
            half_result = in1[3:0] + in2[3:0];
            z = full_result[7:0] == 0;
            n = 0;
            c = full_result[8];
            h = half_result[4];
        end
        `ADC: begin
            full_result = in1 + in2 + carry_in;
            half_result = in1[3:0] + in2[3:0] + carry_in;
            z = full_result[7:0] == 0;
            n = 0;
            c = full_result[8];
            h = half_result[4];
        end
        `SUB: begin
            full_result = in1 - in2;
            half_result = in1[3:0] - in2[3:0];
            z = full_result[7:0] == 0;
            n = 1;
            c = full_result[8];
            h = half_result[4];
        end
        `RLC: begin
            full_result = {1'b0, in1[6:0], in1[7]};
            z = (in2 == `a) ? 0 : full_result[7:0] == 0;
            n = 0;
            h = 0;
            c = in1[7];
        end
        `RRC: begin
            full_result = {1'b0, in1[0], in1[7:1]};
            z = (in2 == `a) ? 0 : full_result[7:0] == 0;
            n = 0;
            h = 0;
            c = in1[0];
        end
        `RL: begin
            full_result = {1'b0, in1[6:0], carry_in};
            z = (in2 == `a) ? 0 : full_result[7:0] == 0;
            n = 0;
            h = 0;
            c = in1[7];
        end
        `RR: begin
            full_result = {1'b0, carry_in, in1[7:1]};
            z = (in2 == `a) ? 0 : full_result[7:0] == 0;
            n = 0;
            h = 0;
            c = in1[0];
        end
        `CPL: begin
            full_result = {1'b0, ~in1};
            n = 1;
            h = 1;
        end
        `SCF: begin
            c = 1;
            n = 0;
            h = 0;
        end
        `CCF: begin
            c = ~carry_in;
            n = 0;
            h = 0;
        end
        endcase

    end
endmodule