module RegisterFile ( clk, r1, r2, din, next, do1, do2, addr );

    input wire clk;
    input wire [7:0] din;
    input wire [15:0] next;
    input wire [2:0] r1, r2;
    output wire [7:0] do1, do2;
    output wire [15:0] addr;
    
    Register #(8)
        A (),
        F (),
        B (),
        C (),
        D (),
        E (),
        H (),
        L ();
        
    Register #(16)
        PC (),
        SP ();

endmodule