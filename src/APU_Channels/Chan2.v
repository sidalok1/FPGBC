`default_nettype none
// Pulse channel without frequency sweep
module Chan2 (
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

    `ifdef DEBUG
    reg dbg_we_regs;
    `endif

    //  |       WAVE_DUTY       |                         INITIAL_LENGTH_TIMER                          |
    //  |          R/W          |                                   W/O                                 |
    localparam [7:0] NR21_rd_mask = 8'b11_000000;
    reg [7:0] NR21_reg = 8'b0;
    reg [7:0] NR21_reg_n;
    wire [1:0] WAVE_DUTY = NR21_reg[7:6];
    wire [5:0] INITIAL_LENGTH_TIMER = NR21_reg[5:0];

    //  |                INITIAL_VOLUME                 |  ENV_DIR  |             SWEEP_PACE            |
    //  |                     R/W                       |    R/W    |                R/W                |  
    localparam [7:0] NR22_rd_mask = 8'hFF;
    reg [7:0] NR22_reg = 8'b0;
    reg [7:0] NR22_reg_n;
    wire [3:0] INITIAL_VOLUME = NR22_reg[7:4];
    wire ENV_DIR = NR22_reg[3];
    wire [2:0] ENV_SWEEP_PACE = NR22_reg[2:0];
    reg [3:0] volume = 4'b0;
    reg [3:0] volume_n;

    //  |                                          PERIOD_LOW                                           |
    //  |                                              W/O                                              |
    localparam [7:0] NR23_rd_mask = 8'h00;
    reg [7:0] NR23_reg = 8'b0;  
	reg [7:0] NR23_reg_n;
    wire [7:0] PERIOD_LOW = NR23_reg;

    //  |  TRIGGER  | LENGTH_EN |                 -                 |            PERIOD_HIGH            |
    //  |    W/O    |    R/W    |                                   |                W/O                |
    localparam [7:0] NR24_rd_mask = 8'b0_1_000000;
    reg [7:0] NR24_reg = 8'b0;  
	reg [7:0] NR24_reg_n;
    wire TRIGGER = we == 1 && addr == NR24 && din[7]; // trigger the cycle NR14 is written to
    wire CHANNEL_STATE = NR24_reg[7];
    wire ENABLE_LENGTH = (we == 1 && addr == NR24 && din[6]) || NR24_reg[6];
    wire LENGTH_EN = NR24_reg[6];
    wire [2:0] PERIOD_HIGH = NR24_reg[2:0];

    reg [12:0] period_divider = 13'b0;
    reg [12:0] period_divider_n;

    reg [2:0] env_sweep_timer = 3'b0;
    reg [2:0] env_sweep_timer_n;

    reg [2:0] env_pace_counter = 3'b0;
    reg [2:0] env_pace_counter_n;

    reg [3:0] duty_step_counter = 4'b0;
    reg [3:0] duty_step_counter_n;

    reg [6:0] length_timer = 7'b0, length_timer_n;

    localparam ENABLED = 1;
    localparam DISABLED = 0;
    reg env_sweep_state = DISABLED;
    reg env_sweep_state_n;

    wire [7:0] waveforms [0:3];
    assign waveforms[2'b00] = 8'b01111111;
    assign waveforms[2'b01] = 8'b01111110;
    assign waveforms[2'b10] = 8'b00011110;
    assign waveforms[2'b11] = 8'b10000001;

    always @* begin
        `ifdef DEBUG
        dbg_we_regs = 0;
        `endif
        dout = 8'b0;
        dac_data = 4'b0;
        channel_on = CHANNEL_STATE;
        NR21_reg_n = NR21_reg;
        NR22_reg_n = NR22_reg;
        NR23_reg_n = NR23_reg;
        NR24_reg_n = NR24_reg;
        period_divider_n = period_divider;
        env_sweep_state_n = env_sweep_state;
        env_sweep_timer_n = env_sweep_timer;
        env_pace_counter_n = env_pace_counter;
        duty_step_counter_n = duty_step_counter;
        length_timer_n = length_timer;
        volume_n = volume;

        if ( re ) begin
            case ( addr ) 
                NR21: dout = NR21_reg | ~NR21_rd_mask;
                NR22: dout = NR22_reg | ~NR22_rd_mask;
                NR23: dout = NR23_reg | ~NR23_rd_mask;
                NR24: dout = NR24_reg | ~NR24_rd_mask;
                default:;// 
            endcase
        end
        if ( !apu_on ) begin
            NR21_reg_n = 0;
            NR22_reg_n = 0;
            NR23_reg_n = 0;
            NR24_reg_n = 0;
        end
        else begin
            if ( we ) begin
            `ifdef DEBUG
            dbg_we_regs = 1;
            `endif
                case ( addr )
                    NR21: NR21_reg_n = din;
                    NR22: NR22_reg_n = din;
                    NR23: NR23_reg_n = din;
                    NR24: NR24_reg_n = din;
                    `ifdef DEBUG
                    default: dbg_we_regs = 0;
                    `else
                    default:;//
                    `endif
                endcase
            end

            if ( TRIGGER ) begin
                period_divider_n = {PERIOD_HIGH, PERIOD_LOW, 2'b00};
                env_sweep_timer_n = 3'b0;
                if ( ENABLE_LENGTH )
                    length_timer_n = {INITIAL_LENGTH_TIMER, 1'b0};
                    // Increments every two div_event

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
                                    NR24_reg_n[7] = volume == 4'd1 ? DISABLED : NR24_reg[7];
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
                    if ( LENGTH_EN ) begin
                        if ( we == 1'b1 && addr == NR21 ) begin
                            length_timer_n = {din[5:0], 1'b0};
                        end
                        else if ( length_timer == 7'h7F )
                            NR24_reg_n[7] = DISABLED;
                        else
                            length_timer_n = length_timer + 1;
                    end
                end
                if ( INITIAL_VOLUME == 4'b0 && ENV_DIR == 1'b0 ) begin
                    // According to Pan Docs, writing zero to all there bits does not require
                    // retriggering the channel to have it's effect of turning the channel off
                    NR24_reg_n[7] = DISABLED;
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
            NR21_reg <= 8'b0;
            NR22_reg <= 8'b0;
            NR23_reg <= 8'b0;
            NR24_reg <= 8'b0;
            env_sweep_state <= DISABLED;
            period_divider <= 13'b0;
            env_sweep_timer <= 3'b0;
            env_pace_counter <= 3'b0;
            duty_step_counter <= 4'b0;
            length_timer <= 7'b0;
            volume <= 4'b0;
        end
        else if ( en ) begin
            NR21_reg <= NR21_reg_n;
            NR22_reg <= NR22_reg_n;
            NR23_reg <= NR23_reg_n;
            NR24_reg <= NR24_reg_n;
            env_sweep_state <= env_sweep_state_n;
            period_divider <= period_divider_n;
            env_sweep_timer <= env_sweep_timer_n;
            env_pace_counter <= env_pace_counter_n;
            duty_step_counter <= duty_step_counter_n;
            length_timer <= length_timer_n;
            volume <= volume_n;
        end
    end

endmodule