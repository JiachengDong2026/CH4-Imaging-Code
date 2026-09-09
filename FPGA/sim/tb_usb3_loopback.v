`timescale 1ns/1ps
module tb_usb3_loopback;
 reg hrclk=0,txclk=0,rst_n=0,rx_enable=0,tx_enable=0,hrvld=0,hract=0,htrdy=0;
 reg[31:0]hrd=0;wire htack,htclk,htreq,htvld;wire[31:0]htd;
 wire full,empty,wr_en,rd_en;wire[31:0]wr_data,rd_data;wire rx_done,rx_overflow,tx_done,tx_underflow;
 integer i,received=0,errors=0;
 reg[31:0]expected_crc=32'hFFFFFFFF;
 function[31:0]crc_word;input[31:0]crc_in;input[31:0]data;integer bit_index;reg[31:0]value;begin
  value=crc_in;
  for(bit_index=0;bit_index<32;bit_index=bit_index+1)
   if(value[0]^data[bit_index])value=(value>>1)^32'hEDB88320;else value=value>>1;
  crc_word=value;
 end endfunction
 always #4.166 hrclk=~hrclk;
 always #4.000 txclk=~txclk;
 hspi_async_fifo #(.ADDR_BITS(11))fifo(.wr_clk(hrclk),.wr_rst(!rst_n),.wr_en(wr_en),.wr_data(wr_data),.full(full),
  .rd_clk(txclk),.rd_rst(!rst_n),.rd_en(rd_en),.rd_data(rd_data),.empty(empty));
 hspi_loopback_rx rx(.rst_n(rst_n),.enable(rx_enable),.hrclk(hrclk),.hrvld(hrvld),.hract(hract),.hrd(hrd),.fifo_full(full),
  .htack(htack),.fifo_wr_en(wr_en),.fifo_wr_data(wr_data),.done(rx_done),.overflow(rx_overflow));
 hspi_loopback_tx tx(.clk(txclk),.rst_n(rst_n),.enable(tx_enable),.htrdy(htrdy),.fifo_empty(empty),.fifo_data(rd_data),
  .htclk(htclk),.htreq(htreq),.htvld(htvld),.htd(htd),.fifo_rd_en(rd_en),.done(tx_done),.underflow(tx_underflow));
 always @(posedge txclk)if(htvld)begin
  if(received==0)begin
   if(htd!==32'hC2AAAAAA)begin $display("HEADER_MISMATCH got=%08x",htd);errors=errors+1;end
   expected_crc=crc_word(expected_crc,htd);
  end else if(received<=1024)begin
   if(htd!==(32'h5A000000+(received-1)))begin $display("DATA_MISMATCH index=%0d got=%08x",received-1,htd);errors=errors+1;end
   expected_crc=crc_word(expected_crc,htd);
  end else if(received==1025&&htd!==~expected_crc)begin
   $display("CRC_MISMATCH expected=%08x got=%08x",~expected_crc,htd);errors=errors+1;
  end
  received=received+1;
 end
 initial begin
  repeat(8)@(posedge hrclk);rst_n=1;
  // Match CH569 hardware ordering: Rx_Ctrl edge precedes HRACT.
  @(posedge hrclk);rx_enable=1;@(posedge hrclk);rx_enable=0;
  repeat(6)@(posedge hrclk);hract=1;
  wait(htack);@(posedge hrclk);hrvld=1;hrd=32'hC0000000;@(posedge hrclk);
  for(i=0;i<1024;i=i+1)begin hrd=32'h5A000000+i;@(posedge hrclk);end
  hrd=32'hDEADBEEF;@(posedge hrclk);hrvld=0;hract=0;
  wait(rx_done);repeat(8)@(posedge txclk);tx_enable=1;@(posedge txclk);tx_enable=0;
  wait(htreq);repeat(5)@(posedge txclk);htrdy=1;
  wait(tx_done);repeat(4)@(posedge txclk);
  if(rx_overflow||tx_underflow||errors!=0||received!=1026)begin $display("USB3_LOOPBACK_FAIL errors=%0d words=%0d ov=%b uf=%b",errors,received,rx_overflow,tx_underflow);$fatal;end
  $display("USB3_LOOPBACK_PASS words=%0d",received);$finish;
 end
 initial begin #1000000;$display("USB3_LOOPBACK_TIMEOUT");$fatal;end
endmodule
