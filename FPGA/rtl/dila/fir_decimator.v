module fir_decimator #(parameter integer IN_W=56,COEFF_W=18,ACC_W=64,MAX_TAPS=31,MAX_D=16,OUT_SHIFT=34)(
 input wire clk,rst,clear,in_valid,input wire signed[IN_W-1:0]in_data,
 input wire[$clog2(MAX_TAPS+1)-1:0]tap_count,input wire[$clog2(MAX_D+1)-1:0]decim,
 input wire coeff_we,coeff_bank,input wire[$clog2(MAX_TAPS)-1:0]coeff_addr,input wire signed[COEFF_W-1:0]coeff_wdata,
 input wire active_bank,output reg out_valid,output reg signed[31:0]out_data,output reg overflow);
 reg signed[COEFF_W-1:0]coeff0[0:MAX_TAPS-1],coeff1[0:MAX_TAPS-1];reg signed[IN_W-1:0]delay[0:MAX_TAPS-1];
 reg signed[ACC_W-1:0]acc;integer k;reg[$clog2(MAX_D+1)-1:0]dcount;
 function signed[31:0]sat32;input signed[63:0]x;begin if(x>64'sh0000_0000_7fff_ffff)sat32=32'sh7fff_ffff;
  else if(x< -64'sh0000_0000_8000_0000)sat32=-32'sh8000_0000;else sat32=x[31:0];end endfunction
 initial begin for(k=0;k<MAX_TAPS;k=k+1)begin coeff0[k]=0;coeff1[k]=0;end
  for(k=0;k<16;k=k+1)begin coeff0[k]=18'sd8192;coeff1[k]=18'sd8192;end end
 always @(posedge clk)if(coeff_we)begin if(coeff_bank)coeff1[coeff_addr]<=coeff_wdata;else coeff0[coeff_addr]<=coeff_wdata;end
 always @* begin acc=0;for(k=0;k<MAX_TAPS;k=k+1)if(k<tap_count)acc=acc+$signed(delay[k])*$signed(active_bank?coeff1[k]:coeff0[k]);end
 always @(posedge clk)if(rst||clear)begin out_valid<=0;out_data<=0;overflow<=0;dcount<=0;for(k=0;k<MAX_TAPS;k=k+1)delay[k]<=0;end
 else begin out_valid<=0;if(in_valid)begin for(k=MAX_TAPS-1;k>0;k=k-1)delay[k]<=delay[k-1];delay[0]<=in_data;
  if(dcount>=((decim<2)?1:decim)-1)begin dcount<=0;out_valid<=1;out_data<=sat32((acc+(64'sd1<<<(OUT_SHIFT-1)))>>>OUT_SHIFT);
   overflow<=overflow|((acc>>>OUT_SHIFT)>64'sd2147483647)|((acc>>>OUT_SHIFT)<-64'sd2147483648);end else dcount<=dcount+1'b1;end end
endmodule

