module scan_framer(input wire clk,rst,enable,in_valid,input wire[31:0]scan_points,input wire[63:0]master_tick,
 input wire signed[31:0]i1,q1,i2,q2,output reg point_valid,scan_start,scan_end,
 output reg[31:0]point_index,output reg signed[31:0]out_i1,out_q1,out_i2,out_q2);
 reg[31:0]next_index;wire[31:0]effective=(scan_points<2)?2:scan_points;
 always @(posedge clk)if(rst)begin point_valid<=0;scan_start<=0;scan_end<=0;point_index<=0;next_index<=0;out_i1<=0;out_q1<=0;out_i2<=0;out_q2<=0;end
 else begin point_valid<=0;scan_start<=0;scan_end<=0;if(!enable)next_index<=0;else if(in_valid)begin point_valid<=1;point_index<=next_index;out_i1<=i1;out_q1<=q1;out_i2<=i2;out_q2<=q2;
  scan_start<=(next_index==0);scan_end<=(next_index>=effective-1);if(next_index>=effective-1)next_index<=0;else next_index<=next_index+1'b1;end end
endmodule

