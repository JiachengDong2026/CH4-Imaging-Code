// Deterministic Z-raster used only when no physical mirror is connected.
module sim_raster_position #(parameter integer WIDTH=50)(
 input wire clk,rst,enable,advance,input wire signed[15:0]x_min_q13,x_max_q13,y_min_q13,y_max_q13,
 input wire[15:0]height,output reg signed[15:0]x_q13,y_q13,
 output reg[31:0]image_id,output reg[15:0]line_id,point_id,output reg reverse,
 output reg image_begin,image_end,line_event);
 integer span;reg[15:0]column;
 always @(posedge clk)begin
  if(rst)begin x_q13<=0;y_q13<=0;image_id<=0;line_id<=0;point_id<=0;column<=0;reverse<=0;image_begin<=0;image_end<=0;line_event<=0;end
  else begin image_begin<=0;image_end<=0;line_event<=0;if(!enable)begin line_id<=0;point_id<=0;column<=0;reverse<=0;x_q13<=x_min_q13;y_q13<=y_min_q13;end
   else if(advance)begin span=x_max_q13-x_min_q13;point_id<=column;
    x_q13<=reverse?(x_max_q13-(column*span)/(WIDTH-1)):(x_min_q13+(column*span)/(WIDTH-1));
    y_q13<=y_min_q13+(line_id*(y_max_q13-y_min_q13))/((height<2)?1:height-1);if(line_id==0&&column==0)image_begin<=1;
    if(column==WIDTH-1)begin column<=0;line_event<=1;if(line_id>=((height<2)?2:height)-1)begin image_end<=1;image_id<=image_id+1'b1;line_id<=0;reverse<=0;end
     else begin line_id<=line_id+1'b1;reverse<=~reverse;end end else column<=column+1'b1;end
  end
 end
endmodule
