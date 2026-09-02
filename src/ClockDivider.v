`default_nettype none
module ClockDivider #(
    parameter real I_CLK_FRQ = 100e6,
    parameter real O_CLK_FRQ = 1
) (
    input wire rst, en,
    input wire i_clk,
    output reg o_clk
);

    localparam integer DIV = int'(I_CLK_FRQ / O_CLK_FRQ);

generate
    if ( DIV <= 1 ) begin : no_clock_division
        always @* begin
            o_clk = en;
        end
    end
    else begin : clock_division
        localparam WIDTH = $clog2(DIV);
        localparam [WIDTH-1:0] divider = DIV;

        reg [WIDTH-1:0] counter, counter_n;

        always @ ( posedge i_clk ) begin
            if ( rst ) begin
                counter <= 0;
            end
            else if ( en ) begin
                counter <= counter_n;
            end
        end

        always @* begin
            if ( counter == divider - 1 )
                counter_n = 0;
            else
                counter_n = counter + 1;
            if ( counter == 0 )
                o_clk = 1;
            else
                o_clk = 0;
        end
    end
endgenerate

endmodule