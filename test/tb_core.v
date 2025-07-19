`timescale 1ns / 1ps

`define NOP 8'b00000000 
`define LDI16SP 8'b00001000

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
        memory.mem[0] = `NOP;
        memory.mem[1] = `LDI16SP;
        memory.mem[2] = 8'h05;
        memory.mem[3] = 8'h00;
        memory.mem[4] = `NOP;
        UUT.regfile.r8[10] = 8'hab;
        UUT.regfile.r8[11] = 8'hcd;

        for (i = 0; i < 16; i = i + 1) begin
            $dumpvars(0, tb_core.memory.mem[i]);
            // $dumpvars(0, tb_core.UUT.regfile.r8[i]);
        end


        // runtime
        #100 $finish();

    end

endmodule