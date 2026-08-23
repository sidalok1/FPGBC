`default_nettype none
module Chan4 (
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

    //  |           -           |                         INITIAL_LENGTH_TIMER                          |
    //  |                       |                                   W/O                                 |
    localparam [7:0] NR41_rd_mask = 8'h00;
    reg [7:0] NR41_reg = 8'b0;
    reg [7:0] NR41_reg_n;
    wire [5:0] INITIAL_LENGTH_TIMER = NR41_reg[5:0];

    //  |                INITIAL_VOLUME                 |  ENV_DIR  |             SWEEP_PACE            |
    //  |                     R/W                       |    R/W    |                R/W                |  
    localparam [7:0] NR42_rd_mask = 8'hFF;
    reg [7:0] NR42_reg = 8'b0;
    reg [7:0] NR42_reg_n;
    wire [3:0] INITIAL_VOLUME = NR42_reg[7:4];
    wire ENV_DIR = NR42_reg[3];
    wire [2:0] ENV_SWEEP_PACE = NR42_reg[2:0];
    reg [3:0] volume = 4'b0;
    reg [3:0] volume_n;

    //  |                 CLOCK_SHIFT                   |   WIDTH   |           CLOCK_DIVIDER           |
    //  |                     R/W                       |    R/W    |                R/W                | 
    localparam [7:0] NR43_rd_mask = 8'hFF;
    reg [7:0] NR43_reg = 8'b0;  
	reg [7:0] NR43_reg_n;
    wire [3:0] CLOCK_SHIFT = NR43_reg[7:4];
    wire WIDTH = NR43_reg[3];
    localparam SHORT_MODE = 1;
    wire [2:0] CLOCK_DIVIDER = NR43_reg[2:0];

    //  |  TRIGGER  | LENGTH_EN |                                   -                                   |
    //  |    W/O    |    R/W    |                                                                       |
    localparam [7:0] NR44_rd_mask = 8'b0_1_000000;
    reg [7:0] NR44_reg = 8'b0;  
	reg [7:0] NR44_reg_n;
    wire TRIGGER = we == 1 && addr == NR44 && din[7]; // trigger the cycle NR14 is written to
    wire CHANNEL_STATE = NR44_reg[7];
    wire ENABLE_LENGTH = (we == 1 && addr == NR44 && din[6]) || NR44_reg[6];
    wire LENGTH_EN = NR44_reg[6];

    reg [19:0] counter = 20'b0;
    reg [19:0] counter_n;
    reg [21:0] divider;
    reg [3:0] divider_base;

    reg [15:0] lfsr = 16'b0, lfsr_n;
    reg feedback_bit;

    reg [2:0] env_sweep_timer = 3'b0;
    reg [2:0] env_sweep_timer_n;

    reg [2:0] env_pace_counter = 3'b0;
    reg [2:0] env_pace_counter_n;

    reg [6:0] length_timer = 7'b0, length_timer_n;

    localparam ENABLED = 1;
    localparam DISABLED = 0;
    reg env_sweep_state = DISABLED;
    reg env_sweep_state_n;

    // The following python snippet shows the logic behind selecting the divider
    /*
    dot_clk = 4194316
    pandoc_magic_num = dot_clk / 16 # 262144.75
    for i in range(8):
        if i == 0:
            i = 0.5
        for j in range(14):
            print(f"{i = :.1f}, 2**{j = :02d}, count = {int(dot_clk/(pandoc_magic_num/(i*(2**j)))):020b}")
    */
    // By running the above snippet it can be seen that when clocked at the dot clock, the
    // counter treats the divider as a UQ3.1 number (where divider == 0 is mapped to UQ3.1[000.1] == 0.5)
    // and left shifts this base number by 3 + clock_shift bits. The resulting number can require as much
    // as 22 bits, but requires only 20 if clock_shift is < 14, hence why the counter is 20 bits


    always @* begin
        `ifdef DEBUG
        dbg_we_regs = 0;
        `endif
        dout = 8'b0;
        dac_data = 4'b0;
        NR41_reg_n = NR41_reg;
        NR42_reg_n = NR42_reg;
        NR43_reg_n = NR43_reg;
        NR44_reg_n = NR44_reg;
        lfsr_n = lfsr;
        volume_n = volume;
        feedback_bit = ~(lfsr[0] ^ lfsr[1]);
        counter_n = (CLOCK_SHIFT != 4'd15 && CLOCK_SHIFT != 4'd14) ?
            counter + 1 :
            counter;
        
        channel_on = CHANNEL_STATE;

        if ( CLOCK_DIVIDER == 0 )
            divider_base = 4'b0001;
        else
            divider_base = {CLOCK_DIVIDER, 1'b0};
        divider = 22'(divider_base) << (CLOCK_SHIFT + 3);
        

        if ( re ) begin
            case ( addr ) 
                NR41: dout = NR41_reg | ~NR41_rd_mask;
                NR42: dout = NR42_reg | ~NR42_rd_mask;
                NR43: dout = NR43_reg | ~NR43_rd_mask;
                NR44: dout = NR44_reg | ~NR44_rd_mask;
                default:;// 
            endcase
        end
        if ( !apu_on ) begin
            NR41_reg_n = 0;
            NR42_reg_n = 0;
            NR43_reg_n = 0;
            NR44_reg_n = 0;
        end
        else begin
            if ( we ) begin
            `ifdef DEBUG
            dbg_we_regs = 1;
            `endif
                case ( addr )
                    NR41: NR41_reg_n = din;
                    NR42: NR42_reg_n = din;
                    NR43: NR43_reg_n = din;
                    NR44: NR44_reg_n = din;
                    `ifdef DEBUG
                    default: dbg_we_regs = 0;
                    `else
                    default:;//
                    `endif
                endcase
            end

            if ( TRIGGER ) begin
                counter_n = 20'b0;
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

                lfsr_n = 16'b0;
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
                                    volume_n = volume -1;
                                    NR44_reg_n[7] = volume == 4'd1 ? DISABLED : NR44_reg[7];
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
                        if ( we == 1'b1 && addr == NR41 ) begin
                            length_timer_n = {din[5:0], 1'b0};
                        end
                        else if ( length_timer == 7'h7F )
                            NR44_reg_n[7] = DISABLED;
                        else
                            length_timer_n = length_timer + 1;
                    end
                end
                if ( INITIAL_VOLUME == 4'b0 && ENV_DIR == 1'b0 ) begin
                    // According to Pan Docs, writing zero to all there bits does not require
                    // retriggering the channel to have it's effect of turning the channel off
                    NR44_reg_n[7] = DISABLED;
                end
                if ( 22'(counter) == divider - 1 ) begin
                    counter_n = 20'b0;
                    lfsr_n = {feedback_bit, lfsr[15:1]};
                    if ( WIDTH == SHORT_MODE )
                        lfsr_n[7] = feedback_bit;
                    
                end
                dac_data = lfsr[0] == 1'b1 ?
                    volume :
                    4'b0;
            end
        end
    end

    always @ ( posedge clk ) begin
        if ( rst ) begin
            NR41_reg <= 8'b0;
            NR42_reg <= 8'b0;
            NR43_reg <= 8'b0;
            NR44_reg <= 8'b0;
            counter <= 20'b0;
            env_sweep_state <= DISABLED;
            env_sweep_timer <= 3'b0;
            env_pace_counter <= 3'b0;
            lfsr <= 16'b0;
            volume <= 4'b0;
            length_timer <= 7'b0;
        end
        else if ( en ) begin
            NR41_reg <= NR41_reg_n;
            NR42_reg <= NR42_reg_n;
            NR43_reg <= NR43_reg_n;
            NR44_reg <= NR44_reg_n;
            counter <= counter_n;
            env_sweep_state <= env_sweep_state_n;
            env_sweep_timer <= env_sweep_timer_n;
            env_pace_counter <= env_pace_counter_n;
            lfsr <= lfsr_n;
            volume <= volume_n;
            length_timer <= length_timer_n;
        end
    end

endmodule