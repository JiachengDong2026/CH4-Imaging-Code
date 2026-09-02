// Reused from DILA_260823. See Docs/复用代码来源.md.
module uart_tx #(parameter integer CLK_HZ=100_000_000,BAUD=921600)(
 input wire clk,rst,start,input wire [7:0] data,output reg tx,busy,done);
 localparam integer DIV=(CLK_HZ+BAUD/2)/BAUD;localparam integer CW=$clog2(DIV+1);
 reg [CW-1:0] count;reg [3:0] bitno;reg [9:0] shift;
 always @(posedge clk)begin
  if(rst)begin tx<=1;busy<=0;done<=0;count<=0;bitno<=0;shift<=10'b1111111111;end else begin done<=0;
   if(start&&!busy)begin shift<={1'b1,data,1'b0};tx<=0;busy<=1;count<=DIV-1;bitno<=0;end
   else if(busy)begin if(count!=0)count<=count-1'b1;else begin count<=DIV-1;shift<={1'b1,shift[9:1]};bitno<=bitno+1'b1;
    if(bitno==9)begin busy<=0;tx<=1;done<=1;end else tx<=shift[1];end end
  end
 end
endmodule

