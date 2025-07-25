`timescale 1ns / 1ps

// `define NOP         8'b00000000 
// `define LDI16SP     8'b00001000
// `define ADDHLSP     8'b00111001
// `define LDR16I16    8'b00000001
// `define JRI8        8'b00011000

module tb_core();

    reg clk = 1, wake = 0;
    wire [7:0] core_din;
    wire [7:0] core_dout;
    wire [15:0] core_addrbus;
    wire core_write;

    always #5 clk = ~clk;

    Core UUT( clk, core_din, core_dout, core_addrbus, core_write, wake );

    Testmem memory( clk, core_addrbus, core_write, core_dout, core_din );
    
    always @ ( posedge clk ) 
        $display("%0t", $time);

    integer i;
    initial begin
        $dumpvars(0, tb_core);
        // setup
        // memory.mem[0]   = `NOP;
        // memory.mem[1]   = `LDI16SP;
        // memory.mem[2]   = 8'h0e;
        // memory.mem[3]   = 8'h00;
        // memory.mem[4]   = `ADDHLSP;
        // memory.mem[5]   = `LDR16I16;
        // memory.mem[6]   = 8'h34;
        // memory.mem[7]   = 8'h12;
        // memory.mem[8]   = `JRI8;
        // memory.mem[9]   = 8'd3;
        // memory.mem[10]  = `LDR16I16;
        // memory.mem[11]  = 8'hff;
        // memory.mem[12]  = 8'hff;
        
        // UUT.regfile.r8[10] = 8'hab;
        // UUT.regfile.r8[11] = 8'hcd;

        $readmemb("test/rom.mem", memory.mem);

        for (i = 0; i < 16; i = i + 1) begin
            $dumpvars(0, tb_core.UUT.regfile.r8[i]);
        end
        for (i = 0; i < 256; i = i + 1)begin
            $dumpvars(0, tb_core.memory.mem[i]);
        end


        // runtime
        #150 $finish();

    end

endmodule