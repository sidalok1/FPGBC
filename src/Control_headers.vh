`ifndef CONTROL_H
`define CONTROL_H



// mask for writeback to flags register
`define fz 4'b1000
`define fn 4'b0100
`define fh 4'b0010
`define fc 4'b0001

// data bus in select
`define din 0
`define alu 1

// states
`define s0 'b00001
`define s1 'b00010
`define s2 'b00100
`define s3 'b01000
`define s4 'b10000

`define max_state 5;

`define INVALID_STATE(mnemonic) $display("---\nERROR\ninstruction:\n\t%s\nhas no defined state:\n\t%d\n", mnemonic, state);
`endif