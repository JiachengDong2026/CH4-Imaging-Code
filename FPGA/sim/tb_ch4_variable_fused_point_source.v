`timescale 1ns / 1ps
module tb_ch4_variable_fused_point_source;
 reg clk=0,rst=1; wire valid; wire[383:0] payload; integer count=0; integer changes=0;
 reg[31:0] first_i1=0, second_i1=0;
 ch4_real_fused_point_source #(.GAS_VARIATION(1)) dut(.clk(clk),.rst(rst),.curve_rate_hz(32'd2000),.fused_valid(valid),.fused_payload(payload));
 always #10 clk=~clk;
 always @(posedge clk) if(valid) begin
   count=count+1;
   if(count==1) first_i1=payload[191:160];
   if(count==2) begin second_i1=payload[191:160]; if(second_i1!==first_i1) changes=changes+1; end
   if(count>2 && payload[191:160]!==second_i1) changes=changes+1;
 end
 initial begin
   repeat(4) @(posedge clk); rst=0; wait(count>=5);
   if(changes==0) $fatal(1,"variable gas source produced constant I/Q");
   $display("VARIABLE_FUSED_POINT_SOURCE_PASS count=%0d changes=%0d first_i1=%0d second_i1=%0d",count,changes,first_i1,second_i1);
   $finish;
 end
 initial begin #10000000; $fatal(1,"timeout count=%0d",count); end
endmodule
