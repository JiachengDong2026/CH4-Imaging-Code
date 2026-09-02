// Free-running 50 MHz hardware time. One tick is 20 ns on the target board.
module system_timebase(
    input wire clk,
    input wire rst,
    output reg [63:0] ticks
);
    always @(posedge clk) begin
        if (rst)
            ticks <= 64'd0;
        else
            ticks <= ticks + 1'b1;
    end
endmodule

