module iq_boxcar16(input wire clk,rst,clear,in_valid,input wire signed[31:0]i1,q1,i2,q2,
 output reg out_valid,output reg signed[31:0]oi1,oq1,oi2,oq2);
 reg signed[31:0]di1[0:15],dq1[0:15],di2[0:15],dq2[0:15];reg signed[35:0]si1,sq1,si2,sq2;reg[3:0]ptr;integer k;
 wire signed[35:0]ni1=si1-{{4{di1[ptr][31]}},di1[ptr]}+{{4{i1[31]}},i1};wire signed[35:0]nq1=sq1-{{4{dq1[ptr][31]}},dq1[ptr]}+{{4{q1[31]}},q1};
 wire signed[35:0]ni2=si2-{{4{di2[ptr][31]}},di2[ptr]}+{{4{i2[31]}},i2};wire signed[35:0]nq2=sq2-{{4{dq2[ptr][31]}},dq2[ptr]}+{{4{q2[31]}},q2};
 always @(posedge clk)if(rst||clear)begin ptr<=0;si1<=0;sq1<=0;si2<=0;sq2<=0;out_valid<=0;oi1<=0;oq1<=0;oi2<=0;oq2<=0;
  for(k=0;k<16;k=k+1)begin di1[k]<=0;dq1[k]<=0;di2[k]<=0;dq2[k]<=0;end end else begin out_valid<=0;if(in_valid)begin
   di1[ptr]<=i1;dq1[ptr]<=q1;di2[ptr]<=i2;dq2[ptr]<=q2;ptr<=ptr+1'b1;si1<=ni1;sq1<=nq1;si2<=ni2;sq2<=nq2;
   oi1<=ni1>>>4;oq1<=nq1>>>4;oi2<=ni2>>>4;oq2<=nq2>>>4;out_valid<=1;end end
endmodule
