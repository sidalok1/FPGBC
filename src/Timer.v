`default_nettype none
module Timer (
    input wire clk, en, rst,
    input wire [15:0] addr,
    input wire [7:0] din,
    output reg [7:0] dout,
    input wire we, re,
    input wire stop,
    output reg time_intr,
    input wire dbl_spd,
    output reg div_apu_event,
    output reg [13:0] system_counter
);

    `include "RegMap.vh"

    //  |                                              DIV                                              |
    //  |                                              R/W                                              |
    reg [13:0] SYS_COUNT_reg = 14'b0;  
	reg [13:0] SYS_COUNT_reg_n;
    wire [7:0] DIV_reg = SYS_COUNT_reg[13:6];

    //  |                                             TIMA                                              |
    //  |                                              R/W                                              |
    reg [7:0] TIMA_reg = 8'b0;  
	reg [7:0] TIMA_reg_n;

    //  |                                              TMA                                              |
    //  |                                              R/W                                              |
    reg [7:0] TMA_reg = 8'b0;  
	reg [7:0] TMA_reg_n;

    //  |                             -                             |  ENABLE   |     CLOCK_SELECT      |
    //  |                                              R/W                                              | 
    reg [7:0] TAC_reg = 8'b0;  
	reg [7:0] TAC_reg_n;
    wire ENABLE = TAC_reg[2];
    wire [1:0] CLOCK_SELECT = TAC_reg[1:0];

    reg div_tick_reg, div_tick_reg_n;
    reg tima_tick_reg, tima_tick_reg_n;
    reg apu_stick_reg, apu_stick_reg_n;
    reg apu_dtick_reg, apu_dtick_reg_n;

    always @ ( posedge clk ) begin
        if ( rst ) begin
            TIMA_reg <= 0;
            TMA_reg <= 0;
            TAC_reg <= 0;
            SYS_COUNT_reg <= 0;
            div_tick_reg <= 0;
            tima_tick_reg <= 0;
            apu_stick_reg <= 0;
            apu_dtick_reg <= 0;
        end
        else if ( en ) begin
            SYS_COUNT_reg <= SYS_COUNT_reg_n;
            TIMA_reg <= TIMA_reg_n;
            TMA_reg <= TMA_reg_n;
            TAC_reg <= TAC_reg_n;
            div_tick_reg <= div_tick_reg_n;
            tima_tick_reg <= tima_tick_reg_n;
            apu_stick_reg <= apu_stick_reg_n;
            apu_dtick_reg <= apu_dtick_reg_n;
        end
    end

    wire div_negedge = ~div_tick_reg_n & div_tick_reg;
    wire tima_negedge = ~tima_tick_reg_n & tima_tick_reg;
    wire apu_snegedge = ~apu_stick_reg_n & apu_stick_reg;
    wire apu_dnegedge = ~apu_dtick_reg_n & apu_dtick_reg;

    always @* begin
        system_counter = SYS_COUNT_reg;
        dout = 8'b0;
        time_intr = 0;
        SYS_COUNT_reg_n = SYS_COUNT_reg + 1;
        TIMA_reg_n = TIMA_reg;
        TMA_reg_n = TMA_reg;
        TAC_reg_n = TAC_reg;
        tima_tick_reg_n = TIMA_reg[7];
        apu_stick_reg_n = SYS_COUNT_reg[11];
        apu_dtick_reg_n = SYS_COUNT_reg[10];
        div_apu_event = dbl_spd ? apu_dnegedge & en : apu_snegedge & en;

        case ( CLOCK_SELECT )
            2'b00: div_tick_reg_n = SYS_COUNT_reg[7];
            2'b01: div_tick_reg_n = SYS_COUNT_reg[1];
            2'b10: div_tick_reg_n = SYS_COUNT_reg[3];
            2'b11: div_tick_reg_n = SYS_COUNT_reg[5];
            default:; // All cases captured
        endcase

        if ( ENABLE ) begin
            if ( div_negedge ) begin
                TIMA_reg_n = TIMA_reg + 1;
            end
            else if ( tima_negedge ) begin
                TIMA_reg_n = TMA_reg;
                time_intr = 1;
            end
        end

        if ( stop )
            SYS_COUNT_reg_n = 14'b0;
        else if ( we ) begin
            case ( addr )
                DIV: SYS_COUNT_reg_n = 14'b1;
                TIMA:begin
                    TIMA_reg_n = din;
                    tima_tick_reg_n = 0;
                    time_intr = 0;
                end
                TMA: TMA_reg_n = din;
                TAC: TAC_reg_n = din;
                default:; // 
            endcase
        end
        if ( re ) begin
            case ( addr )
                DIV:    dout = DIV_reg;
                TIMA:   dout = TIMA_reg_n;
                TMA:    dout = TMA_reg;
                TAC:    dout = TAC_reg;
                default:dout = 8'b0; 
            endcase
        end
    end

endmodule