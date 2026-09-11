`timescale 1ns/1ps
// Small dual-clock FIFO used by the isolated USB3.0 loopback target.
// DEPTH must be a power of two. One slot is intentionally left unused.
module hspi_async_fifo #(
 parameter integer WIDTH = 32,
 parameter integer ADDR_BITS = 11
)(
 input wire wr_clk,input wire wr_rst,input wire wr_en,input wire[WIDTH-1:0]wr_data,output wire full,
 input wire rd_clk,input wire rd_rst,input wire rd_en,output wire[WIDTH-1:0]rd_data,output wire empty
);
 localparam integer PTR_BITS=ADDR_BITS+1;
 reg[WIDTH-1:0]mem[0:(1<<ADDR_BITS)-1];
 reg[PTR_BITS-1:0]wr_bin,wr_gray,rd_bin,rd_gray;
 (* ASYNC_REG="TRUE" *) reg[PTR_BITS-1:0]rd_gray_w1,rd_gray_w2,wr_gray_r1,wr_gray_r2;
 wire[PTR_BITS-1:0]wr_bin_next=wr_bin+(wr_en&&!full);
 wire[PTR_BITS-1:0]rd_bin_next=rd_bin+(rd_en&&!empty);
 wire[PTR_BITS-1:0]wr_gray_next=(wr_bin_next>>1)^wr_bin_next;
 wire[PTR_BITS-1:0]rd_gray_next=(rd_bin_next>>1)^rd_bin_next;
 wire[PTR_BITS-1:0]wr_bin_plus_one=wr_bin+1'b1;
 wire[PTR_BITS-1:0]wr_gray_plus_one=(wr_bin_plus_one>>1)^wr_bin_plus_one;
 wire[PTR_BITS-1:0]full_compare={~rd_gray_w2[PTR_BITS-1:PTR_BITS-2],rd_gray_w2[PTR_BITS-3:0]};
 assign full=(wr_gray_plus_one==full_compare);
 assign empty=(rd_gray==wr_gray_r2);
 assign rd_data=mem[rd_bin[ADDR_BITS-1:0]];
 always @(posedge wr_clk)begin
  if(wr_rst)begin wr_bin<=0;wr_gray<=0;rd_gray_w1<=0;rd_gray_w2<=0;end
  else begin rd_gray_w1<=rd_gray;rd_gray_w2<=rd_gray_w1;if(wr_en&&!full)begin mem[wr_bin[ADDR_BITS-1:0]]<=wr_data;wr_bin<=wr_bin_next;wr_gray<=wr_gray_next;end end
 end
 always @(posedge rd_clk)begin
  if(rd_rst)begin rd_bin<=0;rd_gray<=0;wr_gray_r1<=0;wr_gray_r2<=0;end
  else begin wr_gray_r1<=wr_gray;wr_gray_r2<=wr_gray_r1;if(rd_en&&!empty)begin rd_bin<=rd_bin_next;rd_gray<=rd_gray_next;end end
 end
endmodule
