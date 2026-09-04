module adc_calibration #(parameter integer W=16)(input wire clk,rst,in_valid,input wire signed[W-1:0]in_sample,
 input wire signed[31:0]offset,gain_q16,output reg out_valid,output reg signed[W-1:0]out_sample,output reg saturated);
 reg signed[W:0]shifted;reg signed[W+32:0]scaled;reg signed[32:0]rounded;
 always @*begin shifted=$signed(in_sample)+$signed(offset);scaled=shifted*$signed(gain_q16);rounded=(scaled+(1<<<15))>>>16;end
 always @(posedge clk)if(rst)begin out_valid<=0;out_sample<=0;saturated<=0;end else begin out_valid<=in_valid;saturated<=0;if(in_valid)begin
  if(rounded>((1<<<(W-1))-1))begin out_sample<=(1<<<(W-1))-1;saturated<=1;end else if(rounded<-(1<<<(W-1)))begin out_sample<=-(1<<<(W-1));saturated<=1;end
  else out_sample<=rounded[W-1:0];end end
endmodule

