// Reused from DILA_260823. See Docs/复用代码来源.md.
module sync_fifo #(parameter integer W=8,DEPTH=1024)(
 input wire clk,rst,input wire wr_en,input wire [W-1:0] wr_data,
 input wire rd_en,output wire [W-1:0] rd_data,output wire empty,full,
 output reg [$clog2(DEPTH+1)-1:0] count,output reg overflow);
 reg [W-1:0] mem[0:DEPTH-1];reg [$clog2(DEPTH)-1:0] wp,rp;
 assign empty=(count==0);assign full=(count==DEPTH);assign rd_data=mem[rp];
 always @(posedge clk) begin
  if(rst) begin wp<=0;rp<=0;count<=0;overflow<=0;end else begin
   case({wr_en,rd_en&&!empty})
    2'b10:if(!full)begin mem[wp]<=wr_data;wp<=wp+1'b1;count<=count+1'b1;end else overflow<=1;
    2'b01:begin rp<=rp+1'b1;count<=count-1'b1;end
    2'b11:begin mem[wp]<=wr_data;wp<=wp+1'b1;rp<=rp+1'b1;end default:;
   endcase
  end
 end
endmodule

