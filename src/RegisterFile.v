

module RegisterFile ( 
    clk, 
    rd, din, flags_in, mask, flags_out,
    r1, r2, ctr, alu1, alu2,
    addr, addrh, addrl, idu, rd_idu
    );

    `include "RegFile_params.vh"

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

    reg [3:0] flags = 0;

    assign alu1 = r8[r1];
    assign alu2 = r8[r2];
    assign addr = {r8[addrh], r8[addrl]};

    integer i;
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            r8[i] = 0;
        end
        
        r8[ONE] = 8'b1;
    end

    assign flags_out = flags;

    always @ ( posedge clk ) begin
        case ( rd )
        B, C, D, E, H, 
        L, A, PCH, PCL, 
        SPH, SPL, W, Z: r8[rd] <= din;
        CTR, ONE, F:; // garbage writes
        endcase

        if ( mask[4] ) begin
            r8[F][7:4] <= (flags_in & mask[3:0]) | (r8[F][7:4] & ~mask[3:0]);
            flags <= (flags_in & mask[3:0]) | (r8[F][7:4] & ~mask[3:0]);
        end

        case ( rd_idu )
        BC: {r8[B], r8[C]} <= idu;
        DE: {r8[D], r8[E]} <= idu;
        HL: {r8[H], r8[L]} <= idu;
        SP: {r8[SPH], r8[SPL]} <= idu;
        PC: {r8[PCH], r8[PCL]} <= idu;
        WZ: {r8[W], r8[Z]} <= idu;
        _W: r8[W] <= idu[7:0];
        FF:; // garbage writes
        endcase
    end

    always @( ctr ) begin
        r8[CTR] = ctr;
    end

endmodule