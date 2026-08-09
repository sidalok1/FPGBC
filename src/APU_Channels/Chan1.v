`default_nettype none
// Pulse channel with frequency sweep
module Chan1 (
    input wire clk, rst, en, div_event,
    input wire [15:0] addr,
    input wire [7:0] din,
    output reg [7:0] dout,
    input wire we, re,
    output reg [3:0] dac_data,
    output reg channel_on,
    input wire apu_on
);

    `include "RegMap.vh"

    //  |     -     |                PACE               | DIRECTION |           INDIVIDUAL_STEP         |
    //  |                                              R/W                                              | 
    wire [7:0] NR10_rd_mask = 8'hFF;
    reg [7:0] NR10_reg = 8'b0;  
	reg [7:0] NR10_reg_n;
    wire [2:0] PACE = NR10_reg[6:4];
    wire DIRECTION = NR10_reg[3];
    wire [2:0] INDIVIDUAL_STEP = NR10_reg[2:0];

    //  |       WAVE_DUTY       |                         INITIAL_LENGTH_TIMER                          |
    //  |          R/W          |                                   W/O                                 |
    wire [7:0] NR11_rd_mask = 8'b11_000000;
    reg [7:0] NR11_reg = 8'b0;
    reg [7:0] NR11_reg_n;
    wire [1:0] WAVE_DUTY = NR11_reg[7:6];
    wire [5:0] INITIAL_LENGTH_TIMER = NR11_reg[5:0];

    //  |                INITIAL_VOLUME                 |  ENV_DIR  |             SWEEP_PACE            |
    //  |                     R/W                       |    R/W    |                R/W                |  
    wire [7:0] NR12_rd_mask = 8'hFF;
    reg [7:0] NR12_reg = 8'b0;
    reg [7:0] NR12_reg_n;
    wire [3:0] INITIAL_VOLUME = NR12_reg[7:4];
    wire ENV_DIR = NR12_reg[3];
    wire [2:0] ENV_SWEEP_PACE = NR12_reg[2:0];
    reg [3:0] volume = 4'b0;
    reg [3:0] volume_n;
    

    //  |                                          PERIOD_LOW                                           |
    //  |                                              W/O                                              |
    wire [7:0] NR13_rd_mask = 8'h00;
    reg [7:0] NR13_reg = 8'b0;  
	reg [7:0] NR13_reg_n;
    wire [7:0] PERIOD_LOW = NR13_reg;

    //  |  TRIGGER  | LENGTH_EN |                 -                 |            PERIOD_HIGH            |
    //  |    W/O    |    R/W    |                                   |                W/O                |
    wire [7:0] NR14_rd_mask = 8'b0_1_111_000;
    reg [7:0] NR14_reg = 8'b0;  
	reg [7:0] NR14_reg_n;
    wire TRIGGER = we == 1 && addr == NR14 && din[7]; // trigger the cycle NR14 is written to
    wire CHANNEL_STATE = NR14_reg[7];
    wire ENABLE_LENGTH = (we == 1 && addr == NR14 && din[6]) || NR14_reg[6];
    wire LENGTH_EN = NR14_reg[6];
    wire [2:0] PERIOD_HIGH = NR14_reg[2:0];

    reg [10:0] calculated_period = 11'b0;
    reg [10:0] calculated_period_n;
    reg period_overflow = 0, period_overflow_n;

    reg [12:0] period_divider = 13'b0;
    reg [12:0] period_divider_n;

    reg [1:0] sweep_timer = 2'b0;
    reg [1:0] sweep_timer_n;
    reg [2:0] env_sweep_timer = 3'b0;
    reg [2:0] env_sweep_timer_n;

    reg [2:0] pace_counter = 3'b0;
    reg [2:0] pace_counter_n;
    reg [2:0] env_pace_counter = 3'b0;
    reg [2:0] env_pace_counter_n;

    reg [3:0] duty_step_counter = 4'b0;
    reg [3:0] duty_step_counter_n;

    reg [6:0] length_timer = 7'b0, length_timer_n;

    localparam ENABLED = 1;
    localparam DISABLED = 0;
    reg sweep_state = DISABLED;
    reg sweep_state_n;
    reg env_sweep_state = DISABLED;
    reg env_sweep_state_n;

    wire [7:0] waveforms [0:3];
    assign waveforms[2'b00] = 8'b01111111;
    assign waveforms[2'b01] = 8'b01111110;
    assign waveforms[2'b10] = 8'b00011110;
    assign waveforms[2'b11] = 8'b10000001;

    always @* begin
        dout = 8'b0;
        dac_data = 4'b0;
        NR10_reg_n = NR10_reg;
        NR11_reg_n = NR11_reg;
        NR12_reg_n = NR12_reg;
        NR13_reg_n = NR13_reg;
        NR14_reg_n = NR14_reg;
        calculated_period_n = calculated_period;
        period_overflow_n  = period_overflow;
        period_divider_n = period_divider;
        sweep_state_n = sweep_state;
        sweep_timer_n = div_event ? sweep_timer + 1 : sweep_timer;
        pace_counter_n = pace_counter;
        duty_step_counter_n = duty_step_counter;
        length_timer_n = length_timer;
        channel_on = CHANNEL_STATE;
        volume_n = volume;

        if ( re ) begin
            case ( addr ) 
                NR10: dout = NR10_reg & NR10_rd_mask;
                NR11: dout = NR11_reg & NR11_rd_mask;
                NR12: dout = NR12_reg & NR12_rd_mask;
                NR13: dout = NR13_reg & NR13_rd_mask;
                NR14: dout = NR14_reg & NR14_rd_mask;
                default:;// 
            endcase
        end
        if ( !apu_on ) begin
            NR10_reg_n = 0;
            NR11_reg_n = 0;
            NR12_reg_n = 0;
            NR13_reg_n = 0;
            NR14_reg_n = 0;
        end 
        else begin
            if ( we ) begin
                case ( addr )
                    NR10: NR10_reg_n = din;
                    NR11: NR11_reg_n = din;
                    NR12: NR12_reg_n = din;
                    NR13: NR13_reg_n = din;
                    NR14: NR14_reg_n = din;
                    default:;// 
                endcase
            end

            if ( TRIGGER ) begin
                calculated_period_n = {PERIOD_HIGH, PERIOD_LOW};
                period_divider_n = {PERIOD_HIGH, PERIOD_LOW, 2'b00};
                sweep_timer_n = 2'b0;
                env_sweep_timer_n = 3'b0;
                if ( ENABLE_LENGTH )
                    length_timer_n = {INITIAL_LENGTH_TIMER, 1'b0};
                    // Increments every two div_event

                pace_counter_n = 3'b0;
                if ( PACE | INDIVIDUAL_STEP )
                    sweep_state_n = ENABLED;
                else
                    sweep_state_n = DISABLED;

                if ( INDIVIDUAL_STEP ) begin
                    {period_overflow_n, calculated_period_n} = DIRECTION ? 
                        calculated_period - (12'($signed(calculated_period)) >>> INDIVIDUAL_STEP) :
                        calculated_period + (12'($signed(calculated_period)) >>> INDIVIDUAL_STEP) ;
                end

                volume_n = INITIAL_VOLUME;
                env_pace_counter_n = 3'b0;
                if ( ENV_SWEEP_PACE != 3'b0 )
                    env_sweep_state_n = ENABLED;
                else 
                    env_sweep_state_n = DISABLED;
            end
            else if ( CHANNEL_STATE == ENABLED ) begin
                if ( div_event ) begin // 512 Hz
                    if ( env_sweep_state == ENABLED ) begin
                        if ( env_sweep_timer == 3'b111 ) begin
                            env_sweep_timer_n = 3'b0;
                            if ( env_pace_counter == ENV_SWEEP_PACE ) begin
                                env_pace_counter_n = 0;
                                if ( ENV_DIR == 1'b1 ) begin
                                    volume_n = volume == 4'hF ? volume : volume + 1;
                                end
                                else begin
                                    volume_n = volume - 1;
                                    NR14_reg_n[7] = volume == 4'd1 ? DISABLED : NR14_reg[7];
                                end
                            end
                            else begin
                                env_pace_counter_n = env_pace_counter + 1;
                            end
                        end
                        else begin
                            env_sweep_timer_n = env_sweep_timer + 1;
                        end
                    end
                    if ( sweep_state == ENABLED ) begin
                        if ( sweep_timer == 2'b11 ) begin
                            sweep_timer_n = 0;
                            {period_overflow_n, calculated_period_n} = DIRECTION ? 
                                calculated_period - (12'($signed(calculated_period)) >>> INDIVIDUAL_STEP) :
                                calculated_period + (12'($signed(calculated_period)) >>> INDIVIDUAL_STEP) ;
                            if ( pace_counter == PACE ) begin
                                pace_counter_n = 0;
                                if ( period_overflow == 1'b1 ) begin
                                    NR14_reg_n[7] = DISABLED;
                                end
                                else begin 
                                    {NR14_reg_n[2:0], NR13_reg_n} = calculated_period;
                                end
                            end else begin
                                pace_counter_n = pace_counter + 1;
                            end
                        end
                    end
                    if ( LENGTH_EN ) begin
                        if ( length_timer == 7'h7F )
                            NR14_reg_n[7] = DISABLED;
                        else
                            length_timer_n = length_timer + 1;
                    end
                end
                if ( INITIAL_VOLUME == 4'b0 && ENV_DIR == 1'b0 ) begin
                    // According to Pan Docs, writing zero to all there bits does not require
                    // retriggering the channel to have it's effect of turning the channel off
                    NR14_reg_n[7] = DISABLED;
                end
                if ( period_divider == 13'h1FFF ) begin
                    // since period dividers should be clocked once per four dots, supply the
                    // dot_en as the enable signal and make the "true" period divider increment
                    // four times slower
                    period_divider_n = {PERIOD_HIGH, PERIOD_LOW, 2'b00};
                    duty_step_counter_n = duty_step_counter + 1;
                end
                else begin
                    period_divider_n = period_divider + 1;
                end
                dac_data = waveforms[WAVE_DUTY][duty_step_counter] == 1'b1 ?
                    volume :
                    4'b0;
            end
        end
    end

    always @ ( posedge clk ) begin
        if ( rst ) begin
            NR10_reg <= 8'b0;
            NR11_reg <= 8'b0;
            NR12_reg <= 8'b0;
            NR13_reg <= 8'b0;
            NR14_reg <= 8'b0;
            sweep_state <= DISABLED;
            env_sweep_state <= DISABLED;
            period_divider <= 13'b0;
            sweep_timer <= 2'b0;
            env_sweep_timer <= 3'b0;
            pace_counter <= 3'b0;
            env_pace_counter <= 3'b0;
            duty_step_counter <= 4'b0;
            calculated_period <= 11'b0;
            period_overflow <= 0;
            volume <= 4'b0;
            length_timer <= 7'b0;
        end
        else if ( en ) begin
            NR10_reg <= NR10_reg_n;
            NR11_reg <= NR11_reg_n;
            NR12_reg <= NR12_reg_n;
            NR13_reg <= NR13_reg_n;
            NR14_reg <= NR14_reg_n;
            sweep_state <= sweep_state_n;
            env_sweep_state <= env_sweep_state_n;
            period_divider <= period_divider_n;
            sweep_timer <= sweep_timer_n;
            env_sweep_timer <= env_sweep_timer_n;
            pace_counter <= pace_counter_n;
            env_pace_counter <= env_pace_counter_n;
            duty_step_counter <= duty_step_counter_n;
            calculated_period <= calculated_period_n;
            period_overflow <= period_overflow_n;
            volume <= volume_n;
            length_timer <= length_timer_n;
        end
    end

endmodule