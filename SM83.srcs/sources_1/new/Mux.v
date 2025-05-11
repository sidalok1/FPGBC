module Mux #( parameter WIDTH = 8 ) ( A, B, S, O );
    localparam ADDR = $clog2(WIDTH);
    input   wire    [WIDTH-1:0] A, B;
    input   wire                S;
    output  wire    [WIDTH-1:0] O;
    
    wire [WIDTH-1:0] X, Y;
    wire N;
    
    not (N, S);
    
    genvar i;
    
    generate
        for ( i = 0; i < WIDTH; i = i + 1 ) 
        begin
            and ( X[i], A[i], N );
            and ( Y[i], B[i], S );
            or ( O[i], X[i], Y[i] );
        end
    endgenerate
    
endmodule
