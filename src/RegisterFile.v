`default_nettype none
module RegisterFile ( 
    clk, en, rst,
    rd, din, flags_in, mask, flags_out, load_flags, clear_flags,
    r1, r2, ctr, alu1, alu2,
    addr, addrh, addrl, idu, rd_idu
    );

    `include "RegFile_params.vh"

    input wire          clk;
    input wire          en;
    input wire          rst;
    input wire  [3:0]   rd;
    input wire  [7:0]   din;

    input wire  [3:0]   flags_in;
    output wire [3:0]   flags_out;
    input wire          load_flags;
    input wire  [3:0]   clear_flags;
    input wire  [4:0]   mask;

    input wire  [3:0]   r1, r2, addrh, addrl;
    input wire  [7:0]   ctr;
    output wire [7:0]   alu1, alu2;

    output wire  [15:0] addr;
    input wire  [15:0]  idu;
    input wire  [2:0]   rd_idu;
    
    reg [7:0] r8 [0:15], r8_n[0:15]; 

    assign alu1 = (r1 == CTR) ? ctr : r8[r1];
    assign alu2 = (r2 == CTR) ? ctr : r8[r2];
    assign addr[15:8] = (addrh == CTR) ? ctr : r8[addrh];
    assign addr[ 7:0] = (addrl == CTR) ? ctr : r8[addrl];

    integer i;
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            r8[i] = 0;
        end
        
        r8[ONE] = 8'd1;
    end

    assign flags_out = r8[F][7:4];

    always @ ( posedge clk ) begin
        if ( rst ) begin
            for ( i = 0; i < 16; i = i + 1 )
                r8[i] <= 0;
            r8[ONE] <= 8'd1;
        end
        else if ( en ) begin
            for ( i = 0; i < 16; i = i + 1 )
                r8[i] <= r8_n[i];
        end
    end

    always @* begin
        for ( i = 0; i < 16; i = i + 1 )
            r8_n[i] = r8[i];
        
        case ( rd_idu )
        BC: {r8_n[B], r8_n[C]} = idu;
        DE: {r8_n[D], r8_n[E]} = idu;
        HL: {r8_n[H], r8_n[L]} = idu;
        SP: {r8_n[SPH], r8_n[SPL]} = idu;
        PC: {r8_n[PCH], r8_n[PCL]} = idu;
        WZ: {r8_n[W], r8_n[Z]} = idu;
        W_: r8_n[W] = idu[15:8];
        FF:; // garbage writes
        default:; // all cases captured
        endcase
        // rd takes precedence over rd_idu, though this should never happen
        case ( rd )
        B, C, D, E, H,
        L, A, PCH, PCL,
        SPH, SPL, W, Z: r8_n[rd] = din;
        CTR, ONE, F:; // garbage writes
        default:; // all cases captured
        endcase

        if ( load_flags ) begin
            r8_n[F][7:4] = din[7:4];
        end
        else if ( mask[4] ) begin
            r8_n[F][7:4] = (flags_in & mask[3:0]) | (r8[F][7:4] & ~mask[3:0]);
        end else begin
            r8_n[F][7:4] = r8[F][7:4] & ~clear_flags;
        end
    end

endmodule
// `default_nettype none
// module RegisterFile ( 
//     clk, en, rst,
//     rd, din, flags_in, mask, flags_out,
//     r1, r2, ctr, alu1, alu2,
//     addr, addrh, addrl, idu, rd_idu
//     );

//     `include "RegFile_params.vh"

//     input wire          clk;
//     input wire          en;
//     input wire          rst;
//     input wire  [3:0]   rd;
//     input wire  [7:0]   din;

//     input wire  [3:0]   flags_in;
//     output wire [3:0]   flags_out;
//     input wire  [4:0]   mask;

//     input wire  [3:0]   r1, r2, addrh, addrl;
//     input wire  [7:0]   ctr;
//     output wire [7:0]   alu1, alu2;

//     output wire  [15:0]  addr;
//     input wire  [15:0]  idu;
//     input wire  [2:0]   rd_idu;
    
//     reg [7:0] r8 [0:15]; 

//     assign alu1 = (r1 == CTR) ? ctr : r8[r1];
//     assign alu2 = (r2 == CTR) ? ctr : r8[r2];
//     assign addr[15:8] = (addrh == CTR) ? ctr : r8[addrh];
//     assign addr[ 7:0] = (addrl == CTR) ? ctr : r8[addrl];


//     integer i;
//     initial begin
//         for (i = 0; i < 16; i = i + 1) begin
//             r8[i] = 0;
//         end
        
//         r8[ONE] = 8'd1;
//     end

//     assign flags_out = r8[F][7:4];

//     always @ ( posedge clk ) begin
//         if ( rst ) begin
//             for ( i = 0; i < 16; i = i + 1 )
//                 r8[i] <= 0;
//             r8[ONE] <= 8'd1;
//         end
//         else if ( en ) begin
//             case ( rd )
//             B, C, D, E, H, 
//             L, A, PCH, PCL, 
//             SPH, SPL, W, Z: r8[rd] <= din;
//             CTR, ONE, F:; // garbage writes
//             default:; // All cases captured
//             endcase

//             if ( mask[4] ) begin
//                 r8[F][7:4] <= (flags_in & mask[3:0]) | (r8[F][7:4] & ~mask[3:0]);
//             end

//             case ( rd_idu )
//             BC: {r8[B], r8[C]} <= idu;
//             DE: {r8[D], r8[E]} <= idu;
//             HL: {r8[H], r8[L]} <= idu;
//             SP: {r8[SPH], r8[SPL]} <= idu;
//             PC: {r8[PCH], r8[PCL]} <= idu;
//             WZ: {r8[W], r8[Z]} <= idu;
//             _W: r8[W] <= idu[7:0];
//             FF:; // garbage writes
//             default:; // All cases captured
//             endcase
//         end
//     end

// endmodule