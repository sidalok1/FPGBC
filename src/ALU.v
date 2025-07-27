`include "ALU_headers.vh"
`include "RegFile_headers.vh"

module ALU ( op, in1, in2, out, flags_in, flags_out );
    input [`ALU_opwidth:0] op;
    input [7:0] in1, in2;
    input [3:0] flags_in;
    output wire [7:0] out;
    output wire [3:0] flags_out;
    
    reg z = 0, n = 0, c = 0, h = 0;
    assign flags_out = {z, n, h, c};

    assign zero = flags_in[3];
    assign half = flags_in[1];
    assign carry = flags_in[0];
    assign subtract = flags_in[2];

    wire daa_off_l, daa_off_h;

    wire [7:0] daa_offsets [0:3];
    assign daa_offsets[0] = 8'h00;
    assign daa_offsets[1] = 8'h06;
    assign daa_offsets[2] = 8'h60;
    assign daa_offsets[3] = 8'h66;
    
    assign daa_off_l = (subtract == 0 && in1[3:0] > 'h09) || half;
    assign daa_off_h = (subtract == 0 && in1 > 'h99) || carry;
    wire [1:0] which_offset;
    assign which_offset = {daa_off_h, daa_off_l};
    wire [7:0] offset;
    assign offset = daa_offsets[which_offset];

    reg [8:0] full_result = 0;
    reg [4:0] half_result = 0;

    assign out = full_result[7:0];

    always @( op, in1, in2, carry, offset ) begin
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
            full_result = in1 + in2 + carry;
            half_result = in1[3:0] + in2[3:0] + carry;
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
            full_result = {1'b0, in1[6:0], carry};
            z = (in2 == `a) ? 0 : full_result[7:0] == 0;
            n = 0;
            h = 0;
            c = in1[7];
        end
        `RR: begin
            full_result = {1'b0, carry, in1[7:1]};
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
            c = ~carry;
            n = 0;
            h = 0;
        end
        `DAA: begin
            full_result = (subtract) ? in1 - offset : in1 + offset;
            z = full_result[7:0] == 0;
            h = 0;
            c = full_result > 'h99 || carry;
        end
        endcase

    end
endmodule