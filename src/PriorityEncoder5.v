`default_nettype none
module PriorityEncoder5 (
    input wire [4:0] i,
    output reg [2:0] o,
    output reg v
);

    always @* begin
        v = |i;
        casez ( i )
        5'b????1: o = 3'd0;
        5'b???10: o = 3'd1;
        5'b??100: o = 3'd2;
        5'b?1000: o = 3'd3;
        5'b10000: o = 3'd4;
        default: o = '1;
        endcase
    end

endmodule