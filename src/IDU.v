`include "ALU_headers.vh"
`include "IDU_headers.vh"

module IDU(
    addr_in,
    op, sign, carry,
    out
);

    input   wire    [15:0]              addr_in;
    input   wire    [`IDU_opwidth:0]    op;
    input   wire                        sign, carry;
    output  reg     [15:0]              out;

    always @( addr_in, op, sign, carry ) begin
        case ( op )
        `ZER: out = addr_in;
        `INC: out = addr_in + 1;
        `DEC: out = addr_in - 1;
        `ADJ: out = 
            (carry & ~sign) ? addr_in + 1 :
            (~carry & sign) ? addr_in - 1 :
                              addr_in;
        endcase
    end

endmodule