`timescale 1ns/1ps
module tb_ch4_real_harmonic_source;
 reg clk=0,rst=1; wire fused_valid,curve_valid;
 wire [383:0] fused_payload; wire [223:0] curve_payload;
 integer count=0; reg [99:0] seen=0;
 ch4_real_fused_point_source dut(.clk(clk),.rst(rst),.curve_rate_hz(32'd2000),.fused_valid(fused_valid),.fused_payload(fused_payload),
   .curve_valid(curve_valid),.curve_payload(curve_payload));
 always #10 clk=~clk;
 always @(posedge clk) if(curve_valid) begin
   if(curve_payload[91:64] > 99) $fatal(1,"invalid sample index %0d",curve_payload[91:64]);
   seen[curve_payload[91:64]] = 1'b1;
   count=count+1;
   if(count==100) begin
     if(seen != {100{1'b1}}) $fatal(1,"missing curve bins %b",seen);
     $display("REAL_HARMONIC_SOURCE_PASS bins=100 i1=%0d i2=%0d",$signed(curve_payload[127:96]),$signed(curve_payload[191:160]));
     $finish;
   end
 end
 initial begin repeat(4) @(posedge clk); rst=0; #100000000; $fatal(1,"timeout count=%0d",count); end
endmodule
