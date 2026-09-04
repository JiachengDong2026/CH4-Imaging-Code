module complex_mixer #(parameter integer SAMPLE_W=16,REF_W=18)(
 input wire clk,rst,in_valid,input wire signed[SAMPLE_W-1:0]sample,
 input wire signed[REF_W-1:0]sin_1f,cos_1f,sin_2f,cos_2f,
 output reg out_valid,output reg signed[SAMPLE_W+REF_W-1:0]i1,q1,i2,q2);
 always @(posedge clk)if(rst)begin out_valid<=0;i1<=0;q1<=0;i2<=0;q2<=0;end else begin out_valid<=in_valid;
  if(in_valid)begin i1<=sample*cos_1f;q1<=sample*sin_1f;i2<=sample*cos_2f;q2<=sample*sin_2f;end end
endmodule

