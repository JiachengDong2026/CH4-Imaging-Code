`timescale 1ns / 1ps
module tb_ch4_real_fused_point_source;
 reg clk=0,rst=1;wire valid;wire[383:0]payload;integer count=0;
 ch4_real_fused_point_source dut(.clk(clk),.rst(rst),.curve_rate_hz(32'd2000),.fused_valid(valid),.fused_payload(payload));
 always #10 clk=~clk;
 always @(posedge clk)if(valid)begin count=count+1;$display("REAL_FUSED_POINT index=%0d time=%0d image=%0d point=%0d flags=%04x",count,payload[63:0],payload[95:64],payload[127:112],payload[367:352]);end
 initial begin repeat(4)@(posedge clk);rst=0;wait(count==2);$display("REAL_FUSED_POINT_SOURCE_PASS count=%0d",count);$finish;end
 initial begin #5000000;$display("FAIL timeout count=%0d",count);$finish;end
endmodule
