`ifndef ALU_H
`define ALU_H

`define ALU_opwidth 4

`define ADD 'b00000
`define ADC 'b00001
`define SUB 'b00010
`define SBC 'b00011
`define AND 'b00100
`define XOR 'b00101
`define OR  'b00110
`define DAA 'b00111

`define RLC 'b01000
`define RRC 'b01001
`define RL  'b01010
`define RR  'b01011

`define CPL 'b01100
`define SCF 'b01101
`define CCF 'b01110
`define PAS 'b01111

`endif