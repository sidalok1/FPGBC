module Testmem ( clk, addr, wen, data, ren );

    input clk, wen, ren;
    input [15:0] addr;
    inout [7:0] data;

    reg [7:0] mem [0:65535];

    assign data = (ren) ? mem[addr] : 'bz;

    integer i;
    initial begin
        for (i = 0; i < 65536; i = i + 1) mem[i] = 0;
    end

    always @( posedge clk ) begin
        if ( wen ) begin
            mem[addr] = data;
        end
    end

endmodule