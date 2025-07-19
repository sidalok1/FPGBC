`include "ALU_headers.vh"

module ALU ( op, in1, in2, out, carry_in, flags_out );
    input [`ALU_opwidth:0] op;
    input [7:0] in1, in2;
    input carry_in;
    output wire [7:0] out;
    output wire flags_out;
    
    reg z, n, c, h;
    assign flags_out = {z, n, c, h};

    reg [8:0] full_result;
    reg [4:0] half_result;

    assign out = full_result[7:0];

    always @( op, in1, in2 ) begin

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
        endcase

    end
endmodule