`include "RegFile_headers.vh"

module RegisterFile ( 
    clk, 
    rd, din, flags_in, mask, flags_out,
    r1, r2, ctr, alu1, alu2,
    addr, addrh, addrl, idu, rd_idu
    );

    input wire          clk;

    input wire  [3:0]   rd;
    input wire  [7:0]   din;

    input wire  [3:0]   flags_in;
    output wire [3:0]   flags_out;
    input wire  [4:0]   mask;

    input wire  [3:0]   r1, r2, addrh, addrl;
    input wire  [7:0]   ctr;
    output wire [7:0]   alu1, alu2;

    output wire  [15:0]  addr;
    input wire  [15:0]  idu;
    input wire  [2:0]   rd_idu;
    
    reg [7:0] r8 [0:15]; 

    reg [3:0] flags;

    assign alu1 = r8[r1];
    assign alu2 = r8[r2];
    assign addr = {r8[addrh], r8[addrl]};

    integer i;
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            r8[i] = 0;
        end
        
        r8[`one] = 8'b1;
    end

    assign flags_out = flags;

    always @ ( posedge clk ) begin
        case ( rd )
        `b, `c, `d, `e, `h, 
        `l, `a, `pch, `pcl, 
        `sph, `spl, `w, `z: r8[rd] <= din;
        `ctr, `one, `f:; // garbage writes
        endcase

        if ( mask[4] ) begin
            r8[`f][7:4] <= (flags_in & mask[3:0]) | (r8[`f][7:4] & ~mask[3:0]);
            flags <= (flags_in & mask[3:0]) | (r8[`f][7:4] & ~mask[3:0]);
        end

        case ( rd_idu )
        `bc: {r8[`b], r8[`c]} <= idu;
        `de: {r8[`d], r8[`e]} <= idu;
        `hl: {r8[`h], r8[`l]} <= idu;
        `sp: {r8[`sph], r8[`spl]} <= idu;
        `pc: {r8[`pch], r8[`pcl]} <= idu;
        `wz: {r8[`w], r8[`z]} <= idu;
        `_w: r8[`w] <= idu[7:0];
        `ff:; // garbage writes
        endcase
    end

    always @( ctr ) begin
        r8[`ctr] = ctr;
    end

endmodule