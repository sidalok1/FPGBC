`default_nettype none
module MBC #(
    parameter mbc_type = 0, // 0 means no MBC
    parameter ROMFILE = ""
) (
    input wire clk, en, rst,
    input wire [15:0] addr,
    input wire [7:0] din,
    output reg [7:0] dout,
    input wire re, we
);

generate case (mbc_type)
0: begin : none_mbc
    reg [7:0] ROM [0:(32*1024)-1];
    reg [14:0] rom_addr = 0;
    wire [7:0] rom_dout = ROM[rom_addr];
    reg [7:0] RAM [0:( 8*1024)-1];
    reg [12:0] ram_addr = 0;
    wire [7:0] ram_dout = RAM[ram_addr];
    reg [7:0] ram_din = 0;
    reg ram_we = 0;

    integer i;
    initial begin
        for ( i = 0; i < 8*1024; i = i + 1 )
            RAM[i] = 0;
        $readmemh(ROMFILE, ROM);
    end

    always @ ( posedge clk ) begin
        // if ( rst ) begin
            
        // end
        // else 
        if ( en ) begin
            if ( ram_we )
                RAM[ram_addr] <= ram_din;
        end
    end

    always @* begin 
        dout = 0;
        rom_addr = 0;
        ram_addr = 0;
        ram_din = 0;
        ram_we = 0;

        if ( addr < 16'h8000 ) begin
            rom_addr = addr;
            if ( re )
                dout = rom_dout;
            // if ( we ) do nothing for writes to ROM
        end
        else
        if ( addr >= 16'hA000 && addr <= 16'hBFFF ) begin
            ram_addr = addr - 16'hA000;
            if ( re )
                dout = ram_dout;
            if ( we ) begin
                ram_din = din;
                ram_we = 1;
            end 
        end
    end
end
endcase endgenerate

endmodule