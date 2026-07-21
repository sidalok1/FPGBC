`default_nettype none
module ClockDivider #(
    parameter I_CLK_FRQ = 100_000_000,
    parameter O_CLK_FRQ = 1
) (
    input wire rst, en,
    input wire i_clk,
    output reg o_clk
);

    localparam DIV = I_CLK_FRQ / O_CLK_FRQ;
    localparam WIDTH = $clog2(DIV);

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
        if ( counter == DIV - 1 )
            counter_n = 0;
        else
            counter_n = counter + 1;
        if ( counter == 0 )
            o_clk = 1;
        else
            o_clk = 0;
    end

endmodule