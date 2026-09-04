`timescale 1ns/1ps

module tb_fast_mirror_link;
 localparam integer CLOCK_HZ=1_000_000, BAUD=100_000, BIT_NS=10_000;
 reg clk=0,rst=1,scan_enable=0,scan_start=0,mirror_rx=1;
 always #500 clk=~clk;
 wire mirror_tx,feedback_valid,scan_finished;wire signed [15:0] feedback_x,feedback_y;wire [31:0] feedback_errors;
 fast_mirror_link #(.CLOCK_HZ(CLOCK_HZ),.MIRROR_BAUD(BAUD)) dut(
  .clk(clk),.rst(rst),.scan_enable(scan_enable),.scan_start(scan_start),.x_min(-16'sd1000),.x_max(16'sd1000),.y_min(-16'sd500),.y_max(16'sd500),.static_x(16'sd0),.static_y(16'sd0),
  .x_frequency_mhz(32'd10000),.frame_frequency_mhz(32'd10000),.scan_policy(1'b1),.feedback_hz(16'd2500),.mirror_rx(mirror_rx),.mirror_tx(mirror_tx),
  .feedback_valid(feedback_valid),.feedback_x(feedback_x),.feedback_y(feedback_y),.feedback_errors(feedback_errors),.scan_finished(scan_finished));

 wire tx_valid;wire [7:0] tx_data;
 fast_mirror_uart_rx #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) monitor(.clk(clk),.rst(rst),.rx(mirror_tx),.valid(tx_valid),.data(tx_data));
 reg [3:0] tx_count=0;reg [7:0] tx_frame[0:8];integer frame_count=0;integer y_step_frames=0;
 always @(posedge clk) if(tx_valid) begin
  tx_frame[tx_count]<=tx_data;
  if(tx_count==8) begin
   if(tx_data!=8'hcc)$fatal(1,"missing frame tail");
   if(tx_frame[0]!=8'h55||tx_frame[1]!=8'haa)$fatal(1,"missing native frame header");
   if(tx_frame[7]!=(tx_frame[2]^tx_frame[3]^tx_frame[4]^tx_frame[5]^tx_frame[6]^8'hff))$fatal(1,"bad outgoing XOR");
   frame_count=frame_count+1;
   if({tx_frame[3],tx_frame[4]}==16'sd1000&&{tx_frame[5],tx_frame[6]}!=-16'sd500)y_step_frames=y_step_frames+1;
   tx_count<=0;
  end else tx_count<=tx_count+1'b1;
 end

 function [7:0] native_xor;
  input [7:0] freq,xh,xl,yh,yl;
  begin native_xor=freq^xh^xl^yh^yl^8'hff;end
 endfunction
 task send_byte;input [7:0] value;integer bit_no;begin
  mirror_rx=0;#(BIT_NS);
  for(bit_no=0;bit_no<8;bit_no=bit_no+1)begin mirror_rx=value[bit_no];#(BIT_NS);end
  mirror_rx=1;#(BIT_NS);
 end endtask
 task send_feedback;input [7:0] freq;input signed [15:0] x;input signed [15:0] y;begin
  send_byte(8'h55);send_byte(8'haa);send_byte(freq);send_byte(x[15:8]);send_byte(x[7:0]);send_byte(y[15:8]);send_byte(y[7:0]);send_byte(native_xor(freq,x[15:8],x[7:0],y[15:8],y[7:0]));send_byte(8'hcc);
 end endtask

 integer feedback_seen=0;
 always @(posedge clk)if(feedback_valid)begin
  feedback_seen=feedback_seen+1;
  if(feedback_x!=-16'sd321||feedback_y!=16'sd123)$fatal(1,"feedback payload was parsed incorrectly");
 end
 initial begin
  repeat(8)@(posedge clk);rst=0;
  // 24 is deliberately different from requested 25.  Valid native feedback
  // must still be accepted, because the mirror may quantize its report rate.
  send_feedback(8'd24,-16'sd321,16'sd123);
  wait(feedback_seen==1);
  if(feedback_errors!=0)$fatal(1,"valid feedback incremented the error counter");
  scan_enable=1;
  // 0.10 s is a two-row image at 10 Hz.  The waveform policy must issue
  // commands throughout the raster, make an endpoint Y update, then stop.
  repeat(140000)@(posedge clk);
  if(frame_count<80)$fatal(1,"too few mirror commands: %0d",frame_count);
  if(y_step_frames<1)$fatal(1,"no endpoint Y-step frame was transmitted");
  if(!scan_finished)$fatal(1,"scan did not report completion");
  begin : verify_scan_stops
   integer completed_frame_count;
   completed_frame_count=frame_count;
   repeat(30000)@(posedge clk);
   if(frame_count!=completed_frame_count)$fatal(1,"scan continued after its final row");
  end
  $display("FAST_MIRROR_LINK_PASS frames=%0d y_steps=%0d feedback=%0d",frame_count,y_step_frames,feedback_seen);
  $finish;
 end
 initial begin #250_000_000;$fatal(1,"fast-mirror link test timeout");end
endmodule
