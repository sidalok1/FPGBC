// Constants related to Register File

// alu/data addressing for r1, r2, and/or rd
localparam  B = 0,
            C = 1,
            D = 2,
            E = 3,
            H = 4,
            L = 5,
            F = 6,
            A = 7,
            PCH = 8,
            PCL = 9,
            SPH = 10,
            SPL = 11,
            W = 12,
            Z = 13,
            CTR = 14,
            ONE = 15;

// idu rd addressing
localparam  BC = 0,
            DE = 1,
            HL = 2,
            SP = 3,
            PC = 4,
            WZ = 5,
            _W = 6,
            FF = 7;
