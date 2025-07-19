module Testmem ( clk, addr, wen, in, out );

    input clk, wen;
    input [15:0] addr;
    input [7:0] in;
    output wire [7:0] out;

    reg [7:0] mem [0:65535];

    assign out = mem[addr];

    integer i;
    initial begin
        for (i = 0; i < 65536; i = i + 1) mem[i] = 0;
    end

    always @( posedge clk ) begin
        if ( wen ) begin
            mem[addr] = in;
        end
    end

endmodule