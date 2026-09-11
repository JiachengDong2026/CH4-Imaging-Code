`timescale 1ns/1ps
module tb_usb_harmonic_multi_block_source;
 reg clk=0,rst=1,block_start=0,curve_valid=0,word_ready=1;
 reg [223:0] curve_payload=0;
 wire block_ready,curve_ready,word_valid,word_last,busy,block_done,frame_too_long;
 wire [31:0] word_data;
 reg [7:0] captured[0:4095]; integer words=0, i, bytes;
 usb_harmonic_multi_block_source dut(
   .clk(clk),.rst(rst),.block_start(block_start),.block_ready(block_ready),
   .curve_valid(curve_valid),.curve_payload(curve_payload),.curve_ready(curve_ready),
   .word_valid(word_valid),.word_data(word_data),.word_last(word_last),
   .word_ready(word_ready),.busy(busy),.block_done(block_done),.frame_too_long(frame_too_long));
 always #5 clk=~clk;
 task offer(input integer marker);
   begin
     @(negedge clk); while(!curve_ready) @(negedge clk);
     curve_payload={196'd0, marker[27:0]}; curve_valid=1;
     @(negedge clk); curve_valid=0;
   end
 endtask
 always @(posedge clk) if(word_valid && word_ready) begin
   captured[words*4]=word_data[7:0]; captured[words*4+1]=word_data[15:8];
   captured[words*4+2]=word_data[23:16]; captured[words*4+3]=word_data[31:24];
   if(word_last) begin
     if(words!=1023) $fatal(1,"early last word %0d",words);
     if(frame_too_long) $fatal(1,"frame too long");
     for(i=4059;i<4096;i=i+1) if(captured[i]!==0) $fatal(1,"nonzero padding %0d",i);
     $display("USB_HARMONIC_MULTI_BLOCK_PASS bytes=4096 frames=99 padding=37");
     $finish;
   end else words=words+1;
 end
 initial begin
   repeat(4) @(posedge clk); rst=0; @(negedge clk); block_start=1;
   @(negedge clk); block_start=0;
   for(i=1;i<=99;i=i+1) offer(i);
   #200000; $fatal(1,"timeout words=%0d",words);
 end
endmodule
