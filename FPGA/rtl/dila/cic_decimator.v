module cic_decimator #(parameter integer IN_W=34,ACC_W=56,STAGES=3,MAX_R=4096)(
 input wire clk,rst,clear,in_valid,input wire signed[IN_W-1:0]in_data,
 input wire[$clog2(MAX_R+1)-1:0]decim,output reg out_valid,
 output reg signed[ACC_W-1:0]out_data,output reg overflow);
 reg signed[ACC_W-1:0]integ[0:STAGES-1],delay[0:STAGES-1],next_integ[0:STAGES-1],comb[0:STAGES-1];
 reg[$clog2(MAX_R+1)-1:0]count;integer k,g,gain_shift;reg signed[ACC_W-1:0]normalized;
 always @* begin gain_shift=0;for(g=0;g<$clog2(MAX_R);g=g+1)if(decim[g])gain_shift=g*STAGES;
  normalized=(gain_shift>0)?(comb[STAGES-1]+(56'sd1<<(gain_shift-1)))>>>gain_shift:comb[STAGES-1];end
 always @* begin next_integ[0]=integ[0]+{{(ACC_W-IN_W){in_data[IN_W-1]}},in_data};
  for(k=1;k<STAGES;k=k+1)next_integ[k]=integ[k]+next_integ[k-1];comb[0]=next_integ[STAGES-1]-delay[0];
  for(k=1;k<STAGES;k=k+1)comb[k]=comb[k-1]-delay[k];end
 always @(posedge clk)if(rst||clear)begin count<=0;out_valid<=0;out_data<=0;overflow<=0;
  for(k=0;k<STAGES;k=k+1)begin integ[k]<=0;delay[k]<=0;end end else begin out_valid<=0;if(in_valid)begin
   for(k=0;k<STAGES;k=k+1)integ[k]<=next_integ[k];if(count>=((decim<2)?1:decim)-1)begin count<=0;out_valid<=1;out_data<=normalized;
    delay[0]<=next_integ[STAGES-1];for(k=1;k<STAGES;k=k+1)delay[k]<=comb[k-1];end else count<=count+1'b1;end end
endmodule

