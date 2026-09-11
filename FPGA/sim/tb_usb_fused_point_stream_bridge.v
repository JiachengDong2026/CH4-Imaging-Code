`timescale 1ns / 1ps
module tb_usb_fused_point_stream_bridge;
 localparam integer FRAMES_PER_BLOCK=67,FRAME_BYTES=61;
 reg fused_clk=0,usb_clk=0,fused_rst=1,usb_rst=1,fused_valid=0,word_ready=0,transmit_request=0;
 reg[383:0]fused_payload=0;wire fused_ready,word_valid,word_last,busy,block_done,frame_too_long;wire[31:0]word_data;
 wire[31:0]accepted_frames,launched_frames,dropped_frames;reg[7:0]captured[0:4095];integer word_count=0,block_count=0,offered_count=0,i;
 usb_fused_point_stream_bridge #(.FRAME_FIFO_ADDR_BITS(2)) dut(
  .fused_clk(fused_clk),.fused_rst(fused_rst),.fused_valid(fused_valid),.fused_payload(fused_payload),.fused_ready(fused_ready),
  .usb_clk(usb_clk),.usb_rst(usb_rst),.transmit_request(transmit_request),.word_valid(word_valid),.word_data(word_data),
  .word_last(word_last),.word_ready(word_ready),.busy(busy),.block_done(block_done),.frame_too_long(frame_too_long),
  .accepted_frames(accepted_frames),.launched_frames(launched_frames),.dropped_frames(dropped_frames));
 always #10 fused_clk=~fused_clk;always #4.166 usb_clk=~usb_clk;
 always @(negedge usb_clk)if(!usb_rst)word_ready<=(($time/10)%5!=0);
 function[15:0]crcbyte;input[15:0]ci;input[7:0]d;integer b;reg[15:0]v;begin v=ci^{d,8'h00};for(b=0;b<8;b=b+1)v=v[15]?((v<<1)^16'h1021):(v<<1);crcbyte=v;end endfunction
 task validate_block;input integer bi;integer fi,o,k,seq,marker;reg[15:0]crc,got;begin
  for(fi=0;fi<FRAMES_PER_BLOCK;fi=fi+1)begin o=fi*FRAME_BYTES;seq=bi*FRAMES_PER_BLOCK+fi;marker=seq+1;
   if(captured[o]!==8'hA5||captured[o+1]!==8'h5A||captured[o+2]!==8'h01||captured[o+3]!==0||captured[o+4]!==1||captured[o+5]!==8'h62||captured[o+6]!==8'h40||captured[o+7]!==seq[7:0]||captured[o+8]!==seq[15:8]||captured[o+9]!==48||captured[o+10]!==0||captured[o+11]!==marker[7:0])begin $display("FAIL frame header block=%0d frame=%0d",bi,fi);$finish;end
   crc=16'hffff;for(k=2;k<59;k=k+1)crc=crcbyte(crc,captured[o+k]);got={captured[o+60],captured[o+59]};
   if(got!==crc)begin $display("FAIL frame CRC block=%0d frame=%0d expected=%04x got=%04x",bi,fi,crc,got);$finish;end
  end
  for(k=FRAMES_PER_BLOCK*FRAME_BYTES;k<4096;k=k+1)if(captured[k]!==0)begin $display("FAIL padding block=%0d byte=%0d got=%02x",bi,k,captured[k]);$finish;end
 end endtask
 always @(posedge usb_clk)if(!usb_rst&&word_valid&&word_ready)begin
  captured[word_count*4]=word_data[7:0];captured[word_count*4+1]=word_data[15:8];captured[word_count*4+2]=word_data[23:16];captured[word_count*4+3]=word_data[31:24];
  if(word_last)begin if(word_count!=1023)begin $display("FAIL early last word=%0d",word_count);$finish;end validate_block(block_count);word_count=0;block_count=block_count+1;end else word_count=word_count+1;
 end
 task offer;input[7:0]marker;begin @(negedge fused_clk);while(!fused_ready)@(negedge fused_clk);fused_payload={376'd0,marker};fused_valid=1;@(negedge fused_clk);fused_valid=0;offered_count=offered_count+1;repeat(80)@(posedge usb_clk);end endtask
 task request_block;begin @(negedge usb_clk);transmit_request=0;repeat(3)@(negedge usb_clk);transmit_request=1;end endtask
 initial begin repeat(3)@(posedge fused_clk);fused_rst=0;repeat(3)@(posedge usb_clk);usb_rst=0;
  request_block();for(i=1;i<=FRAMES_PER_BLOCK;i=i+1)offer(i[7:0]);wait(block_count==1);repeat(20)@(posedge usb_clk);
  if(launched_frames!==FRAMES_PER_BLOCK)begin $display("FAIL held request relaunched count=%0d",launched_frames);$finish;end
  request_block();for(i=FRAMES_PER_BLOCK+1;i<=2*FRAMES_PER_BLOCK;i=i+1)offer(i[7:0]);wait(block_count==2);repeat(4)@(posedge fused_clk);
  if(accepted_frames!==2*FRAMES_PER_BLOCK||launched_frames!==2*FRAMES_PER_BLOCK||dropped_frames!==0||frame_too_long)begin $display("FAIL counters accepted=%0d launched=%0d dropped=%0d long=%b",accepted_frames,launched_frames,dropped_frames,frame_too_long);$finish;end
  $display("USB_FUSED_POINT_STREAM_BRIDGE_PASS blocks=%0d frames=%0d padding=9",block_count,launched_frames);$finish;end
 initial begin #10000000;$display("FAIL timeout blocks=%0d words=%0d offered=%0d accepted=%0d launched=%0d frames_started=%0d frame_empty=%b frame_full=%b serializer_busy=%b packer_busy=%b",block_count,word_count,offered_count,accepted_frames,launched_frames,dut.block_source.frames_started,dut.fifo_empty,dut.fifo_full,dut.block_source.serializer_busy,dut.block_source.packer_busy);$finish;end
endmodule
