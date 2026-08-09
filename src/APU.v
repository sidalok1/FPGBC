`default_nettype none
module APU (
    input wire clk, en, rst,
    input wire [15:0] addr,
    input wire [7:0] din,
    output reg [7:0] dout,
    input wire we, re,
    input wire div_apu_event,
    output reg [5:0] dac_left, dac_right
);

    `include "RegMap.vh"

    //  |  VIN_LEFT |            LEFT_VOLUME            | VIN_RIGHT |           RIGHT_VOLUME            |
    //  |                                              R/W                                              |  
    reg [7:0] NR50_reg = 8'b0;  
	reg [7:0] NR50_reg_n;
    //  As of now there are no plans to support VIN
    wire [2:0] LEFT_VOLUME = NR50_reg[6:4];
    wire [2:0] RIGHT_VOLUME = NR50_reg[2:0];

    //  | CH4_LEFT  | CH3_LEFT  | CH2_LEFT  | CH1_LEFT  | CH4_RIGHT | CH3_RIGHT | CH2_RIGHT | CH1_RIGHT |
    //  |                                              R/W                                              |  
    reg [7:0] NR51_reg = 8'b0;
    reg [7:0] NR51_reg_n;
    wire CH4_LEFT = NR51_reg[7];
    wire CH3_LEFT = NR51_reg[6];
    wire CH2_LEFT = NR51_reg[5];
    wire CH1_LEFT = NR51_reg[4];
    wire CH4_RIGHT = NR51_reg[3];
    wire CH3_RIGHT = NR51_reg[2];
    wire CH2_RIGHT = NR51_reg[1];
    wire CH1_RIGHT = NR51_reg[0];

    //  | MASTER_ON |                 -                 |  CH4_ON   |  CH3_ON   |  CH2_ON   |  CH1_ON   |
    //  |    R/W    |                                   |    R/O    |    R/O    |    R/O    |    R/O    |  
    reg [7:0] NR52_reg = 8'b0;
    reg [7:0] NR52_reg_n;
    wire MASTER_ON = NR52_reg[7];

    //  |                   CHANNEL_2                   |                   CHANNEL_1                   |
    //  |                                              R/O                                              |  
    reg [7:0] PCM12_reg;
    wire [3:0] PCM1 = PCM12_reg[3:0];
    wire [3:0] PCM2 = PCM12_reg[7:4];

    //  |                   CHANNEL_4                   |                   CHANNEL_3                   |
    //  |                                              R/O                                              | 
    reg [7:0] PCM34_reg;
    wire [3:0] PCM3 = PCM34_reg[3:0];
    wire [3:0] PCM4 = PCM34_reg[7:4];

    wire [7:0] sig_c1_dout, sig_c2_dout, sig_c3_dout, sig_c4_dout;
    wire [3:0] sig_c1_dac, sig_c2_dac, sig_c3_dac, sig_c4_dac;
    wire sig_c1_on, sig_c2_on, sig_c3_on, sig_c4_on;

    reg [8:0] left_amplified, right_amplified;
    reg [5:0] left_sum, right_sum;

    wire [3:0] c1_left  = CH1_LEFT  ? sig_c1_dac : 4'b0;
    wire [3:0] c1_right = CH1_RIGHT ? sig_c1_dac : 4'b0;
    wire [3:0] c2_left  = CH2_LEFT  ? sig_c2_dac : 4'b0;
    wire [3:0] c2_right = CH2_RIGHT ? sig_c2_dac : 4'b0;
    wire [3:0] c3_left  = CH3_LEFT  ? sig_c3_dac : 4'b0;
    wire [3:0] c3_right = CH3_RIGHT ? sig_c3_dac : 4'b0;
    wire [3:0] c4_left  = CH4_LEFT  ? sig_c4_dac : 4'b0;
    wire [3:0] c4_right = CH4_RIGHT ? sig_c4_dac : 4'b0;

    
    
    Chan1 pulse_channel_with_sweep (
        .clk(clk), .en(en), .rst(rst), .div_event(div_apu_event),
        .addr(addr), .din(din), .dout(sig_c1_dout), .we(we), .re(re),
        .dac_data(sig_c1_dac),
        .channel_on(sig_c1_on), .apu_on(MASTER_ON)
    );

    Chan2 pulse_channel_without_sweep (
        .clk(clk), .en(en), .rst(rst), .div_event(div_apu_event),
        .addr(addr), .din(din), .dout(sig_c2_dout), .we(we), .re(re),
        .dac_data(sig_c2_dac),
        .channel_on(sig_c2_on), .apu_on(MASTER_ON)
    );

    Chan3 waveform_channel (
        .clk(clk), .en(en), .rst(rst), .div_event(div_apu_event),
        .addr(addr), .din(din), .dout(sig_c3_dout), .we(we), .re(re),
        .dac_data(sig_c3_dac),
        .channel_on(sig_c3_on), .apu_on(MASTER_ON)
    );

    Chan4 noise_channel (
        .clk(clk), .en(en), .rst(rst), .div_event(div_apu_event),
        .addr(addr), .din(din), .dout(sig_c4_dout), .we(we), .re(re),
        .dac_data(sig_c4_dac),
        .channel_on(sig_c4_on), .apu_on(MASTER_ON)
    );

    always @* begin
        dout = sig_c1_dout | sig_c2_dout | sig_c3_dout | sig_c4_dout;
        NR50_reg_n = NR50_reg;
        NR51_reg_n = NR51_reg;
        NR52_reg_n = {NR52_reg[7:4], sig_c4_on, sig_c3_on, sig_c2_on, sig_c1_on};
        left_sum = 6'b0;
        right_sum = 6'b0;
        left_amplified = 9'b0;
        right_amplified = 9'b0;
        dac_left = 6'b0;
        dac_right = 6'b0;
        PCM12_reg = {sig_c2_dac, sig_c1_dac};
        PCM34_reg = {sig_c4_dac, sig_c3_dac};

        if ( re ) begin
            case ( addr )
                NR50: dout = NR50_reg;
                NR51: dout = NR51_reg;
                NR52: dout = NR52_reg;
                PCM12:dout = PCM12_reg;
                PCM34:dout = PCM34_reg;
                default:;//
            endcase
        end
        if ( we ) begin
            case ( addr )
                NR50: NR50_reg_n = din;
                NR51: NR51_reg_n = din;
                NR52: NR52_reg_n[7:4] = din[7:4];
                default:;//
            endcase
        end

        if ( MASTER_ON ) begin
            left_sum = 6'(c1_left) + 6'(c2_left) + 6'(c3_left) + 6'(c4_left);
            right_sum = 6'(c1_right) + 6'(c2_right) + 6'(c3_right) + 6'(c4_right);
            left_amplified = left_sum * LEFT_VOLUME;
            right_amplified = right_sum * RIGHT_VOLUME;
            dac_left = left_amplified >> 3;
            dac_right = right_amplified >> 3;
        end
    end

    always @ ( posedge clk ) begin
        if ( rst ) begin
            NR50_reg <= 8'b0;
            NR51_reg <= 8'b0;
            NR52_reg <= 8'b0;
        end
        else if ( en ) begin
            NR50_reg <= NR50_reg_n;
            NR51_reg <= NR51_reg_n;
            NR52_reg <= NR52_reg_n;
        end
    end

endmodule
