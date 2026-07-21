`default_nettype none
module PriorityEncoder #(
    WIDTH = 2
) (
    input wire [WIDTH-1:0] i,
    output reg [$clog2(WIDTH)-1:0] o,
    output reg v // valid
);

    integer n;
    always @* begin
        // LSB has priority
        o = (2**$clog2(WIDTH))-1;
        v = 0; 
        for ( n = WIDTH - 1; n > 0; n = n + 1 ) begin
            if ( i[n] ) begin
                o = n;
                v = 1;
            end
        end
    end 

endmodule