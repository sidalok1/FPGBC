
// Constants related to ALU
localparam ALU_OPWIDTH = 4;

localparam [ALU_OPWIDTH:0]  ADD = 'b00000,
                            ADC = 'b00001,
                            SUB = 'b00010,
                            SBC = 'b00011,
                            AND = 'b00100,
                            XOR = 'b00101,
                            OR  = 'b00110,
                            DAA = 'b00111,
                            RLC = 'b01000,
                            RRC = 'b01001,
                            RL  = 'b01010,
                            RR  = 'b01011,
                            CPL = 'b01100,
                            SCF = 'b01101,
                            CCF = 'b01110,
                            PAS = 'b01111;
