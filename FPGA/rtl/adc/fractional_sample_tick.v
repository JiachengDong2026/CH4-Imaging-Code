module fractional_sample_tick #(parameter integer CLOCK_HZ=50_000_000,SAMPLE_HZ=25_600_000)(
 input wire clk,rst,output reg tick);
 reg[31:0]accumulator;reg[32:0]next_sum;always @*next_sum={1'b0,accumulator}+SAMPLE_HZ;
 always @(posedge clk)if(rst)begin accumulator<=0;tick<=0;end else if(next_sum>=CLOCK_HZ)begin accumulator<=next_sum-CLOCK_HZ;tick<=1;end
 else begin accumulator<=next_sum[31:0];tick<=0;end
endmodule

