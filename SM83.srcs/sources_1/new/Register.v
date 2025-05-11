module Register #( parameter WIDTH = 8 ) ( in, clk, out );
    input   wire    [WIDTH-1:0]     in, clk;
    output  wire    [WIDTH-1:0]     out;

    genvar i;
    wire _;
    
    generate
        for ( i = 0; i < WIDTH; i = i + 1 ) 
        begin
            ff rbit ( .D(in[i]), .CLK(clk), .Q(out[i]), ._Q(_) );        
        end
    endgenerate

endmodule

module ff ( D, CLK, Q, _Q );

    input wire D, CLK;
    output wire Q, _Q;
    
    wire a0, a1, a2, a3;
    
    nand ( a0, D, a1 );
    nand ( a1, a0, CLK, a2 );
    nand ( a2, CLK, a3 );
    nand ( a3, a2, a0 );
    
    nand (_Q, a1, Q );
    nand ( Q, a2, _Q);
    
    

endmodule