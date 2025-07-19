`include "RegFile_headers.vh"

module RegisterFile ( 
    clk, 
    rd, din, flags, mask, carry_out,
    r1, r2, ctr, alu1, alu2,
    addr, addrh, addrl, idu, rd_idu
    );

    input wire          clk;

    input wire  [3:0]   rd;
    input wire  [7:0]   din;

    input wire  [3:0]   flags, mask;
    output wire         carry_out;

    input wire  [3:0]   r1, r2, addrh, addrl;
    input wire  [7:0]   ctr;
    output reg  [7:0]   alu1, alu2;

    output reg  [15:0]  addr;
    input wire  [15:0]  idu;
    input wire  [3:0]   rd_idu;
    
    reg [7:0] r8 [0:15];

    integer i;
    initial begin
        for (i = 0; i <= `a; i = i + 1) r8[i] = 0;
        r8[`one] = 8'b1;
    end

    assign carry_out = r8[`f][4];

    always @ ( posedge clk ) begin

        case ( rd )
        `b, `c, `d, `e, `h, 
        `l, `a, `pch, `pcl, 
        `sph, `spl, `w, `z: r8[rd] <= din;
        `ctr, `one, `f:; // garbage writes
        endcase

        r8[`f][7:4] <= (flags & mask) | (r8[`f][7:4] & ~mask);

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

    always @( r1, r2, addrh, addrl, ctr ) begin

        r8[`ctr] = ctr;

        alu1 = r8[r1];
        alu2 = r8[r2];
        addr[15:8] = r8[addrh];
        addr[7:0] = r8[addrl];

    end

endmodule