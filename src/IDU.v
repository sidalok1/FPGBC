`default_nettype none
module IDU(
    addr_in,
    op, sign, carry,
    out
);

    `include "ALU_params.vh"
    `include "IDU_params.vh"

    input   wire    [15:0]              addr_in;
    input   wire    [IDU_OPWIDTH:0]    op;
    input   wire                        sign, carry;
    output  reg     [15:0]              out;

    always @* begin
        case ( op )
        ZER: out = addr_in;
        INC: out = addr_in + 1;
        DEC: out = addr_in - 1;
        ADJ: out = 
            (carry & ~sign) ? addr_in + (1 << 8) :
            (~carry & sign) ? addr_in - (1 << 8) :
                              addr_in;
        default: out = addr_in;
        endcase
    end

endmodule