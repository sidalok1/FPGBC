`timescale 1ns / 1ps

module tb_reg();

    reg [15:0] a = 0;
    wire [15:0] o;
    reg clk = 0;
    
    always #5 clk = ~clk;
    
    Register #(16) UUT (a, clk, o);
    
    initial
    begin
        a = 16'b1;
        clk = 1;
        clk = 0;
        
        #2 a = 16'h0;
        #5 a = -16'b1;
        #13 a = 16'b0;
        #20 $finish();
    end

endmodule
