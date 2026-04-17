`timescale 1ns / 1ps

module tb_core();

    reg clk = 1, wake = 0;
    wire [15:0] core_addrbus;
    wire [7:0] core_databus;
    wire core_write;
    wire core_read;

    always #5 clk = ~clk;

    Core UUT( clk, core_databus, core_addrbus, core_write, core_read, wake );

    Testmem memory( clk, core_addrbus, core_write, core_databus, core_read );
    
    // always @ ( posedge clk ) 
    //     $display("%0t", $time);

    integer i;
    initial begin
        $dumpvars(0, tb_core);

        $readmemh("test/rom.mem", memory.mem);

        for (i = 0; i < 16; i = i + 1) begin
            $dumpvars(0, tb_core.UUT.regfile.r8[i]);
        end
        for (i = 0; i < 256; i = i + 1)begin
            $dumpvars(0, tb_core.memory.mem[i]);
        end


        // runtime
        #5_000 $finish();

    end

endmodule