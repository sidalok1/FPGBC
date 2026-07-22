`default_nettype none
module PriorityEncoder10 (
    input wire [9:0] i,
    output reg [3:0] o,
    output reg v
);

    always @* begin
        v = |i;
        casez ( i )
        10'b?????????1: o = 4'd0;
        10'b????????10: o = 4'd1;
        10'b???????100: o = 4'd2;
        10'b??????1000: o = 4'd3;
        10'b?????10000: o = 4'd4;
        10'b????100000: o = 4'd5;
        10'b???1000000: o = 4'd6;
        10'b??10000000: o = 4'd7;
        10'b?100000000: o = 4'd8;
        10'b1000000000: o = 4'd9;
        default: o = '1;
        endcase
    end

endmodule