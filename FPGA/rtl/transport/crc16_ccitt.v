// Reused from DILA_260823. CRC-16/CCITT-FALSE, see Docs/复用代码来源.md.
module crc16_ccitt(input wire clk,rst,init,enable,input wire [7:0] data,output reg [15:0] crc);
 integer i;reg [15:0] n;
 always @* begin n=crc^(data<<8);for(i=0;i<8;i=i+1)n=n[15]?(n<<1)^16'h1021:(n<<1);end
 always @(posedge clk)if(rst||init)crc<=16'hffff;else if(enable)crc<=n;
endmodule

