module ch4_rom_source #(parameter integer W=16,DEPTH=12800)(
 input wire clk,rst,enable,advance,output reg valid,scan_start,scan_end,
 output reg signed[W-1:0]sample,output reg[13:0]index);
 reg signed[W-1:0]mem[0:DEPTH-1];
 // Vivado 2020.2 truncates Verilog-2001 string parameters in some flows.
 initial $readmemh("ch4_hitran_5000ppm.mem",mem);
 always @(posedge clk)if(rst)begin index<=0;valid<=0;scan_start<=0;scan_end<=0;sample<=0;end else begin
  valid<=0;scan_start<=0;scan_end<=0;if(enable&&advance)begin valid<=1;sample<=mem[index];scan_start<=(index==0);scan_end<=(index==DEPTH-1);
   if(index==DEPTH-1)index<=0;else index<=index+1'b1;end end
endmodule
