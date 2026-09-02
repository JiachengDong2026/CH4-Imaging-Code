// Reused from DILA_260823. See Docs/复用代码来源.md.
module uart_rx #(parameter integer CLK_HZ=100_000_000,BAUD=921600)(
 input wire clk,rst,rx,output reg valid,output reg [7:0] data,output reg framing_error);
 localparam integer DIV=(CLK_HZ+BAUD/2)/BAUD;
 localparam integer HALF_DIV=DIV/2;
 localparam integer CW=$clog2(DIV+1);
 localparam [1:0] IDLE=2'd0,START=2'd1,DATA_BITS=2'd2,STOP=2'd3;
 (* ASYNC_REG = "TRUE" *) reg rx_meta,rx_sync;
 reg [1:0] state;reg [CW-1:0] count;reg [2:0] bitno;reg [7:0] shift;
 always @(posedge clk)begin
  if(rst)begin rx_meta<=1'b1;rx_sync<=1'b1;end
  else begin rx_meta<=rx;rx_sync<=rx_meta;end
 end
 always @(posedge clk)begin
  if(rst)begin valid<=0;framing_error<=0;state<=IDLE;count<=0;bitno<=0;shift<=0;data<=0;end
  else begin valid<=0;framing_error<=0;
   case(state)
    IDLE:if(!rx_sync)begin state<=START;count<=HALF_DIV-1;end
    START:if(count!=0)count<=count-1'b1;else if(!rx_sync)begin state<=DATA_BITS;count<=DIV-1;bitno<=0;end else state<=IDLE;
    DATA_BITS:if(count!=0)count<=count-1'b1;else begin
     shift[bitno]<=rx_sync;count<=DIV-1;
     if(bitno==7)state<=STOP;else bitno<=bitno+1'b1;
    end
    STOP:if(count!=0)count<=count-1'b1;else begin
     framing_error<=!rx_sync;
     if(rx_sync)begin data<=shift;valid<=1;end
     state<=IDLE;
    end
    default:state<=IDLE;
   endcase
  end
 end
endmodule

