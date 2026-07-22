

// mask for writeback to flags register
// bit 4 is write enable

localparam [4:0]    ZFLAG = 'b11000,
                    NFLAG = 'b10100,
                    HFLAG = 'b10010,
                    CFLAG = 'b10001,
                    ALLFLAG = 'b11111;

// data bus in select
localparam  DIN = 0,
            ALU = 1;

// states
localparam [5:0]    S0 = 'b000001,
                    S1 = 'b000010,
                    S2 = 'b000100,
                    S3 = 'b001000,
                    S4 = 'b010000,
                    S5 = 'b100000;
                    

// `define max_state 5;

`ifdef DEBUG
`define INVALID_STATE(mnemonic) if ( en ) $display("---\nERROR\ninstruction:\n\t%s\nhas no defined state:\n\t%d\n", mnemonic, state);

`define executing(mnemonic) if ( en ) $display("%s\t-\tstate: %6b", mnemonic, state);
`else
`define INVALID_STATE(mnemonic)
`define executing(mnemonic)
`endif
