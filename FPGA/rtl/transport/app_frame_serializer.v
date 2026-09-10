`timescale 1ns / 1ps
`include "protocol_defs.vh"
module app_frame_serializer #(parameter integer PAYLOAD_BYTES=48)(input wire clk,rst,start,input wire[7:0]dst,src,msg_type,flags,
 input wire[15:0]sequence,input wire[PAYLOAD_BYTES*8-1:0]payload,input wire byte_ready,
 output reg byte_valid,output reg[7:0]byte_data,output reg busy,done);
 localparam integer FRAME_BYTES=PAYLOAD_BYTES+13;localparam[15:0]PAYLOAD_LENGTH=PAYLOAD_BYTES;
 reg[12:0]index;reg[15:0]crc;reg[PAYLOAD_BYTES*8-1:0]latched;reg[7:0]current;
 function[15:0]crcbyte;input[15:0]ci;input[7:0]d;integer b;reg[15:0]v;begin v=ci^{d,8'h00};for(b=0;b<8;b=b+1)v=v[15]?((v<<1)^16'h1021):(v<<1);crcbyte=v;end endfunction
 always @*case(index)0:current=`CH4_SOF0;1:current=`CH4_SOF1;2:current=`CH4_PROTOCOL_VERSION;3:current=dst;4:current=src;5:current=msg_type;6:current=flags;
 7:current=sequence[7:0];8:current=sequence[15:8];9:current=PAYLOAD_LENGTH[7:0];10:current=PAYLOAD_LENGTH[15:8];default:begin
  if(index<11+PAYLOAD_BYTES)current=latched[(index-11)*8+:8];else if(index==11+PAYLOAD_BYTES)current=crc[7:0];else current=crc[15:8];end endcase
 always @(posedge clk)if(rst)begin index<=0;crc<=16'hffff;latched<=0;byte_valid<=0;byte_data<=0;busy<=0;done<=0;end else begin byte_valid<=0;done<=0;
  if(start&&!busy)begin index<=0;crc<=16'hffff;latched<=payload;busy<=1;end else if(busy&&byte_ready)begin byte_valid<=1;byte_data<=current;
   if(index>=2&&index<11+PAYLOAD_BYTES)crc<=crcbyte(crc,current);if(index==FRAME_BYTES-1)begin busy<=0;done<=1;end else index<=index+1'b1;end end
endmodule
