// Reused from DILA_260823; coherent 1f/2f reference generator.
module nco #(parameter integer PHASE_W=32,REF_W=18,LUT_AW=14)(
 input wire clk,rst,enable,phase_reset,
 input wire[PHASE_W-1:0]phase_inc,phase_offset_1f,phase_offset_2f,
 output reg valid,output reg signed[REF_W-1:0]sin_1f,cos_1f,sin_2f,cos_2f);
 localparam integer DEPTH=1<<LUT_AW;
 reg[PHASE_W-1:0]phase;reg signed[REF_W-1:0]lut[0:DEPTH-1];integer i;real a;
 initial for(i=0;i<DEPTH;i=i+1)begin a=6.283185307179586*i/DEPTH;lut[i]=$rtoi($sin(a)*((1<<(REF_W-1))-1));end
 reg[PHASE_W-1:0]p1,p2;reg[LUT_AW-1:0]a1,a1c,a2,a2c;
 always @* begin p1=phase+phase_offset_1f;p2=(phase<<1)+phase_offset_2f;
  a1=p1[PHASE_W-1-:LUT_AW];a2=p2[PHASE_W-1-:LUT_AW];a1c=a1+(DEPTH/4);a2c=a2+(DEPTH/4);
  sin_1f=lut[a1];cos_1f=lut[a1c];sin_2f=lut[a2];cos_2f=lut[a2c];end
 always @(posedge clk)if(rst||phase_reset)begin phase<=0;valid<=0;end else begin valid<=enable;if(enable)phase<=phase+phase_inc;end
endmodule

