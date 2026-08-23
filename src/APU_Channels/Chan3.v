`default_nettype none
module Chan3 (
    input wire clk, en, rst, div_event,
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

    //  |    DAC    |                                         -                                         |
    //  |                                              R/W                                              | 
    localparam [7:0] NR30_rd_mask = 8'h80;
    reg [7:0] NR30_reg = 8'b0;  
	reg [7:0] NR30_reg_n;
    wire DAC_ON = NR30_reg[7];

    //  |                                     INITIAL_LENGTH_TIMER                                      |
    //  |                                              W/O                                              |
    localparam [7:0] NR31_rd_mask = 8'h00;
    reg [7:0] NR31_reg = 8'b0;
    reg [7:0] NR31_reg_n;
    wire [7:0] INITIAL_LENGTH_TIMER = NR31_reg[7:0];

    //  |     -     |     OUTPUT_LEVEL      |                            -                              |
    //  |           |          R/W          |                                                           |
    localparam [7:0] NR32_rd_mask = 8'h60;
    reg [7:0] NR32_reg = 8'b0;
    reg [7:0] NR32_reg_n;
    wire [1:0] OUTPUT_LEVEL = NR32_reg[6:5];
    wire [1:0] OUTPUT_SHAMT = OUTPUT_LEVEL - 1; 
    // 00 -> 4 (mute), 01 -> 0 (full volume), 10 -> 1 (divide by two), 11 -> 2 (divide by two)
    

    //  |                                          PERIOD_LOW                                           |
    //  |                                              W/O                                              |
    localparam [7:0] NR33_rd_mask = 8'h00;
    reg [7:0] NR33_reg = 8'b0;  
	reg [7:0] NR33_reg_n;
    wire [7:0] PERIOD_LOW = NR33_reg;

    //  |  TRIGGER  | LENGTH_EN |                 -                 |            PERIOD_HIGH            |
    //  |    W/O    |    R/W    |                                   |                W/O                |
    localparam [7:0] NR34_rd_mask = 8'b0_1_000000;
    reg [7:0] NR34_reg = 8'b0;  
	reg [7:0] NR34_reg_n;
    wire TRIGGER = we == 1 && addr == NR34 && din[7]; // trigger the cycle NR34 is written to
    wire CHANNEL_STATE = NR34_reg[7];
    wire ENABLE_LENGTH = (we == 1 && addr == NR34 && din[6]) || NR34_reg[6];
    wire LENGTH_EN = NR34_reg[6];
    wire [2:0] PERIOD_HIGH = NR34_reg[2:0];

    reg [7:0] WAVE_RAM [0:15];
    wire [3:0] WAVE_RAM_SAMPLES [0:31];
    wire [3:0] waveram_addr = addr - SRAM_LOW;
    reg waveram_we;
    genvar g;
    generate
        for ( g = 0; g < 16; g = g + 1 ) begin
            assign {WAVE_RAM_SAMPLES[2*g], WAVE_RAM_SAMPLES[(2*g)+1]} = WAVE_RAM[g];
        end
    endgenerate
    integer i;
    initial begin
        for ( i = 0; i < 16; i = i + 1 ) begin
            WAVE_RAM[i] = {8{i%2}};
        end
    end
    reg [3:0] sample_buffer = 4'b0, sample_buffer_n;

    reg [11:0] period_divider = 12'b0;
    reg [11:0] period_divider_n;
    // while active, period_divider increments every dot. Documentation says it needs to increment
    // every two dots, hence why it is given an extra bit

    reg [4:0] sample_counter = 5'b0;
    reg [4:0] sample_counter_n;
    

    reg [8:0] length_timer = 9'b0, length_timer_n;

    localparam ENABLED = 1;
    localparam DISABLED = 0;

    always @* begin
        `ifdef DEBUG
        dbg_we_regs = 0;
        `endif
        dout = 8'b0;
        dac_data = 4'b0;
        NR30_reg_n = NR30_reg;
        NR31_reg_n = NR31_reg;
        NR32_reg_n = NR32_reg;
        NR33_reg_n = NR33_reg;
        NR34_reg_n = NR34_reg;
        waveram_we = 0;
        sample_buffer_n = sample_buffer;
        period_divider_n = period_divider;
        sample_counter_n = sample_counter;
        length_timer_n = length_timer;
        channel_on = CHANNEL_STATE & DAC_ON;

        if ( re ) begin
            case ( addr ) 
                NR30: dout = NR30_reg | ~NR30_rd_mask;
                NR31: dout = NR31_reg | ~NR31_rd_mask;
                NR32: dout = NR32_reg | ~NR32_rd_mask;
                NR33: dout = NR33_reg | ~NR33_rd_mask;
                NR34: dout = NR34_reg | ~NR34_rd_mask;
                default: begin
                    if ( addr >= SRAM_LOW && addr <= SRAM_HIGH ) begin
                        dout = WAVE_RAM[waveram_addr];
                    end
                end
            endcase
        end

        if ( !apu_on ) begin
            NR30_reg_n = 0;
            NR31_reg_n = 0;
            NR32_reg_n = 0;
            NR33_reg_n = 0;
            NR34_reg_n = 0;
            if ( we && addr >= SRAM_LOW && addr <= SRAM_HIGH )
                waveram_we = 1;
        end
        else begin 
            if ( we ) begin
            `ifdef DEBUG
            dbg_we_regs = 1;
            `endif
                case ( addr )
                    NR30: NR30_reg_n = din;
                    NR31: NR31_reg_n = din;
                    NR32: NR32_reg_n = din;
                    NR33: NR33_reg_n = din;
                    NR34: NR34_reg_n = din;
                    
                    default: begin
                        if ( addr >= SRAM_LOW && addr <= SRAM_HIGH ) begin
                            waveram_we = 1;
                        end
                        `ifdef DEBUG
                        else
                            dbg_we_regs = 0;
                        `endif
                    end
                endcase
            end

            if ( TRIGGER ) begin
                period_divider_n = {PERIOD_HIGH, PERIOD_LOW, 1'b0};
                if ( ENABLE_LENGTH )
                    length_timer_n = {INITIAL_LENGTH_TIMER, 1'b0};
                    // Increments every two div_event

                sample_counter_n = 0;
            end
            else if ( CHANNEL_STATE == ENABLED ) begin
                if ( div_event ) begin // 512 Hz
                    if ( LENGTH_EN ) begin
                        if ( we == 1'b1 && addr == NR31 ) begin
                            length_timer_n = {din, 1'b0};
                        end
                        else if ( length_timer == 9'h1FF )
                            NR34_reg_n[7] = DISABLED;
                        else
                            length_timer_n = length_timer + 1;
                    end
                end
                if ( period_divider == 12'hFFF ) begin
                    // since period dividers should be clocked once per two dots, supply the
                    // dot_en as the enable signal and make the "true" period divider increment
                    // two times slower
                    period_divider_n = {PERIOD_HIGH, PERIOD_LOW, 1'b0};
                    sample_counter_n = sample_counter + 1;
                    sample_buffer_n = WAVE_RAM_SAMPLES[sample_counter];
                end
                else begin
                    period_divider_n = period_divider + 1;
                end
                dac_data = DAC_ON ? sample_buffer >> OUTPUT_SHAMT : 0;
            end
        end
    end

    always @ ( posedge clk ) begin
        if ( rst ) begin
            NR30_reg <= 8'b0;
            NR31_reg <= 8'b0;
            NR32_reg <= 8'b0;
            NR33_reg <= 8'b0;
            NR34_reg <= 8'b0;
            period_divider <= 13'b0;
            sample_counter <= 0;
            sample_buffer <= 0;
            length_timer <= 9'b0;
            for ( i = 0; i < 16; i = i + 1 )
                WAVE_RAM[i] <= {8{i%2}};
        end
        else if ( en ) begin
            NR30_reg <= NR30_reg_n;
            NR31_reg <= NR31_reg_n;
            NR32_reg <= NR32_reg_n;
            NR33_reg <= NR33_reg_n;
            NR34_reg <= NR34_reg_n;
            period_divider <= period_divider_n;
            sample_buffer <= sample_buffer_n;
            sample_counter <= sample_counter_n;
            length_timer <= length_timer_n;
            if ( waveram_we )
                WAVE_RAM[waveram_addr] <= din;
        end
    end

endmodule