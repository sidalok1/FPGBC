

// mask for writeback to flags register
// bit 4 is write enable
// `define fz 5'b11000
// `define fn 5'b10100
// `define fh 5'b10010
// `define fc 5'b10001
// `define fAll 5'b11111

localparam [4:0]    ZFLAG = 'b11000,
                    NFLAG = 'b10100,
                    HFLAG = 'b10010,
                    CFLAG = 'b10001,
                    ALLFLAG = 'b11111;

// data bus in select
// `define din 0
// `define alu 1
localparam  DIN = 0,
            ALU = 1;

// states
// `define s0 'b00001
// `define s1 'b00010
// `define s2 'b00100
// `define s3 'b01000
// `define s4 'b10000

localparam [4:0]    S0 = 'b00001,
                    S1 = 'b00010,
                    S2 = 'b00100,
                    S3 = 'b01000,
                    S4 = 'b10000;
                    

// `define max_state 5;

`define INVALID_STATE(mnemonic) $display("---\nERROR\ninstruction:\n\t%s\nhas no defined state:\n\t%d\n", mnemonic, state);

`define executing(mnemonic) $display("%s\t-\tstate: %6b", mnemonic, state);

