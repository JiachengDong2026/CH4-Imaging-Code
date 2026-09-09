`timescale 1ns/1ps
// Reflected CRC-32 used by the CH569 HSPI packet trailer.
module hspi_crc32_32(input wire clk,input wire rst,input wire enable,input wire[31:0]data,output reg[31:0]crc);
 integer i;reg[31:0]next;
 always @* begin
  next=crc;
  for(i=0;i<32;i=i+1)begin
   if(next[0]^data[i])next=(next>>1)^32'hEDB88320;else next=next>>1;
  end
 end
 always @(posedge clk)if(rst)crc<=32'hFFFFFFFF;else if(enable)crc<=next;
endmodule
