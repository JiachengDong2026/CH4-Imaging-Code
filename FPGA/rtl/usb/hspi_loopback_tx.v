`timescale 1ns/1ps
module hspi_loopback_tx(
 input wire clk,input wire rst_n,input wire enable,input wire htrdy,input wire fifo_empty,input wire[31:0]fifo_data,
 output wire htclk,output reg htreq,output reg htvld,output reg[31:0]htd,output reg fifo_rd_en,output reg done,output reg underflow
);
 localparam IDLE=3'd0,WAIT_READY=3'd1,HEADER=3'd2,PREFETCH=3'd3,DATA=3'd4,CRC_WAIT=3'd5,TRAILER=3'd6;
 reg[2:0]state;reg[10:0]count;reg[3:0]sequence;reg crc_reset,crc_enable;wire[31:0]crc;
 assign htclk=clk;
 hspi_crc32_32 crc_unit(.clk(clk),.rst(crc_reset),.enable(crc_enable),.data(htd),.crc(crc));
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin state<=IDLE;count<=0;sequence<=0;htreq<=0;htvld<=0;htd<=0;fifo_rd_en<=0;done<=0;underflow<=0;crc_reset<=1;crc_enable<=0;end
  else begin htvld<=0;fifo_rd_en<=0;done<=0;crc_reset<=0;crc_enable<=0;
   case(state)
    IDLE:begin count<=0;crc_reset<=1;if(enable&&!fifo_empty)begin htreq<=1;state<=WAIT_READY;end else htreq<=0;end
    WAIT_READY:if(htrdy)state<=HEADER;
    HEADER:begin htd<={2'b11,sequence,26'h2AAAAAA};htvld<=1;crc_enable<=1;sequence<=sequence+1'b1;state<=PREFETCH;end
    // fifo_rd_en is registered in this block. Start it one cycle before the
    // first payload word so the FIFO pointer and FWFT output stay aligned.
    PREFETCH:begin fifo_rd_en<=1;state<=DATA;end
    DATA:begin
     if(fifo_empty)underflow<=1;
     else begin htd<=fifo_data;htvld<=1;crc_enable<=1;fifo_rd_en<=1;end
     if(count==11'd1023)begin count<=0;state<=CRC_WAIT;end else count<=count+1'b1;
    end
    // The CRC register consumes the last data word on this edge. Keep HTVLD
    // low for one cycle so that word is not sampled twice by CH569.
    CRC_WAIT:state<=TRAILER;
    TRAILER:begin htd<=~crc;htvld<=1;htreq<=0;done<=1;state<=IDLE;end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
