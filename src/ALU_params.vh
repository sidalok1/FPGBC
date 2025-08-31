
// Constants related to ALU
localparam ALU_OPWIDTH = 3;

localparam [ALU_OPWIDTH:0]  ADD = 'b0000,
                            ADC = 'b0001,
                            SUB = 'b0010,
                            SBC = 'b0011,
                            AND = 'b0100,
                            XOR = 'b0101,
                            OR  = 'b0110,
                            DAA = 'b0111,
                            SHR = 'b1000,
                            BIT = 'b1001,
                            RES = 'b1010,
                            SET = 'b1011,
                            CPL = 'b1100,
                            SCF = 'b1101,
                            CCF = 'b1110,
                            PAS = 'b1111;

// Bit shift/rotate operations
localparam [2:0]    RLC = 'b000,
                    RRC = 'b001,
                    RL  = 'b010,
                    RR  = 'b011,
                    SLA = 'b100,
                    SRA = 'b101,
                    SWP = 'b110,
                    SRL = 'b111;