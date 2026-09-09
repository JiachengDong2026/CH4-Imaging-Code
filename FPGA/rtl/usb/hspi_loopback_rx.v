`timescale 1ns/1ps
module hspi_loopback_rx(
 input wire rst_n,input wire enable,input wire hrclk,input wire hrvld,input wire hract,input wire[31:0]hrd,
 input wire fifo_full,output reg htack,output reg fifo_wr_en,output reg[31:0]fifo_wr_data,output reg done,output reg overflow
);
 localparam IDLE=2'd0,HEADER=2'd1,DATA=2'd2,TRAILER=2'd3;
 reg[1:0]state;reg[10:0]count;reg start_pending;
 always @(posedge hrclk or negedge rst_n)begin
  if(!rst_n)begin state<=IDLE;count<=0;start_pending<=0;htack<=0;fifo_wr_en<=0;fifo_wr_data<=0;done<=0;overflow<=0;end
  else begin fifo_wr_en<=0;done<=0;
   // CH569 raises Rx_Ctrl before it starts the HSPI transaction.  Preserve
   // the synchronized one-cycle edge until HRACT arrives; requiring both in
   // the same cycle loses the real hardware transaction.
   if(enable&&state==IDLE)start_pending<=1'b1;
   else if(state==HEADER)start_pending<=1'b0;
   case(state)
    IDLE:begin htack<=0;count<=0;if(start_pending&&hract&&!fifo_full)begin htack<=1;state<=HEADER;end end
    HEADER:if(hrvld)state<=DATA;
    DATA:if(hrvld)begin
     if(fifo_full)overflow<=1;else begin fifo_wr_data<=hrd;fifo_wr_en<=1;end
     if(count==11'd1023)begin count<=0;state<=TRAILER;end else count<=count+1'b1;
    end
    TRAILER:if(hrvld)begin htack<=0;done<=1;state<=IDLE;end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
