module wms_feature_extractor(input wire clk,rst,enable,input wire point_valid,scan_start,scan_end,
 input wire[31:0]point_index,input wire[63:0]master_tick,input wire signed[31:0]i1,q1,i2,q2,
 input wire[31:0]roi_start,roi_end,input wire overflow,saturated,
 output reg result_valid,output reg[63:0]result_time,output reg signed[31:0]result_i1,result_q1,result_i2,result_q2,
 output reg[31:0]result_a1,result_a2,output reg[15:0]quality_flags);
 reg active,found,overflow_seen,saturated_seen;reg[64:0]peak_power;reg signed[31:0]peak_i1,peak_q1,peak_i2,peak_q2;
 wire in_roi=point_index>=roi_start&&point_index<=roi_end&&roi_start<=roi_end;
 wire[63:0]i2sq=$signed(i2)*$signed(i2),q2sq=$signed(q2)*$signed(q2);wire[64:0]power={1'b0,i2sq}+{1'b0,q2sq};
 wire replace=in_roi&&(!found||power>peak_power);wire signed[31:0]fi1=replace?i1:peak_i1,fq1=replace?q1:peak_q1,fi2=replace?i2:peak_i2,fq2=replace?q2:peak_q2;
 always @(posedge clk)if(rst)begin active<=0;found<=0;peak_power<=0;peak_i1<=0;peak_q1<=0;peak_i2<=0;peak_q2<=0;overflow_seen<=0;saturated_seen<=0;
  result_valid<=0;result_time<=0;result_i1<=0;result_q1<=0;result_i2<=0;result_q2<=0;result_a1<=0;result_a2<=0;quality_flags<=0;end
 else begin result_valid<=0;if(!enable)begin active<=0;found<=0;end else if(point_valid)begin
  if(scan_start)begin active<=1;found<=0;peak_power<=0;overflow_seen<=0;saturated_seen<=0;end
  overflow_seen<=overflow_seen|overflow;saturated_seen<=saturated_seen|saturated;if(replace)begin found<=1;peak_power<=power;peak_i1<=i1;peak_q1<=q1;peak_i2<=i2;peak_q2<=q2;end
  if(scan_end&&(active||scan_start))begin active<=0;result_valid<=1;result_time<=master_tick;result_i1<=fi1;result_q1<=fq1;result_i2<=fi2;result_q2<=fq2;
   result_a1<=0;result_a2<=0;
   quality_flags<=16'h00F8|((overflow_seen|overflow)?16'h0200:16'h0000)|((~found&&~replace)?16'h0100:16'h0000);end end end
endmodule
