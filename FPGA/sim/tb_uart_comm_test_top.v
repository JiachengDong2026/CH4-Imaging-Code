`timescale 1ns/1ps
`include "protocol_defs.vh"

module tb_uart_comm_test_top;
 // Exercise the same 921600-baud timing used by the physical USB-UART link.
 // 1085 ns is the nearest whole-nanosecond representation of one bit period.
 localparam integer CLK_HZ=50_000_000,BAUD=921_600,BIT_NS=1085;
 reg clk=0,rst_n=0,host_tx=1;wire device_tx;always #10 clk=~clk;
 ch4_uart_comm_test_top #(.CLOCK_HZ(CLK_HZ),.UART_BAUD(BAUD))dut(.sys_clk(clk),.sys_rst_n(rst_n),.uart_rxd(host_tx),.uart_txd(device_tx));
 wire rxv,rxf;wire[7:0]rxb;uart_rx #(.CLK_HZ(CLK_HZ),.BAUD(BAUD))monitor_rx(.clk(clk),.rst(!rst_n),.rx(device_tx),.valid(rxv),.data(rxb),.framing_error(rxf));
 wire framev,frameerr,crcerr,lenerr,vererr,payloadv;wire[11:0]payload_index;wire[7:0]payload_data;
 wire[7:0]version,dst,src,msg_type,msg_flags;wire[15:0]sequence,payload_length;
 app_frame_rx monitor(.clk(clk),.rst(!rst_n),.byte_valid(rxv),.byte_data(rxb),.payload_valid(payloadv),.payload_index(payload_index),.payload_data(payload_data),.frame_valid(framev),.frame_error(frameerr),.crc_error(crcerr),.length_error(lenerr),.version_error(vererr),.frame_version(version),.frame_dst(dst),.frame_src(src),.frame_type(msg_type),.frame_flags(msg_flags),.frame_sequence(sequence),.frame_payload_length(payload_length));
 integer responses=0,data_frames=0,angle_frames=0,harmonic_frames=0;
 always @(posedge clk)if(framev)begin
  if(msg_type==`CH4_MSG_FUSED_POINT)begin data_frames=data_frames+1;if(payload_length!=48)$fatal(1,"bad fused payload length");end
  else if(msg_type==`CH4_MSG_ANGLE_SAMPLE)begin angle_frames=angle_frames+1;if(payload_length!=16)$fatal(1,"bad angle payload length");end
  else if(msg_type==`CH4_MSG_HARMONIC_CURVE)begin harmonic_frames=harmonic_frames+1;if(payload_length!=28)$fatal(1,"bad harmonic payload length");end
  else if(msg_flags&`CH4_FLAG_IS_RESPONSE)responses=responses+1;
 end
 function[15:0]crc_byte;input[15:0]ci;input[7:0]d;integer b;reg[15:0]v;begin v=ci^{d,8'h00};for(b=0;b<8;b=b+1)v=v[15]?((v<<1)^16'h1021):(v<<1);crc_byte=v;end endfunction
 task send_byte;input[7:0]v;integer i;begin host_tx=0;#(BIT_NS);for(i=0;i<8;i=i+1)begin host_tx=v[i];#(BIT_NS);end host_tx=1;#(BIT_NS);end endtask
 task send_empty_frame;input[7:0]kind;input[15:0]seq;reg[15:0]crc;begin
  crc=16'hffff;crc=crc_byte(crc,8'h01);crc=crc_byte(crc,8'h01);crc=crc_byte(crc,8'h00);crc=crc_byte(crc,kind);crc=crc_byte(crc,`CH4_FLAG_ACK_REQUIRED);crc=crc_byte(crc,seq[7:0]);crc=crc_byte(crc,seq[15:8]);crc=crc_byte(crc,0);crc=crc_byte(crc,0);
 send_byte(8'ha5);send_byte(8'h5a);send_byte(8'h01);send_byte(8'h01);send_byte(8'h00);send_byte(kind);send_byte(`CH4_FLAG_ACK_REQUIRED);send_byte(seq[7:0]);send_byte(seq[15:8]);send_byte(0);send_byte(0);send_byte(crc[7:0]);send_byte(crc[15:8]);end endtask
 task send_stream_config;input[7:0]mask;input[15:0]seq;reg[15:0]crc;begin
  crc=16'hffff;crc=crc_byte(crc,8'h01);crc=crc_byte(crc,8'h01);crc=crc_byte(crc,8'h00);crc=crc_byte(crc,`CH4_MSG_STREAM_CONFIG);crc=crc_byte(crc,`CH4_FLAG_ACK_REQUIRED);crc=crc_byte(crc,seq[7:0]);crc=crc_byte(crc,seq[15:8]);crc=crc_byte(crc,1);crc=crc_byte(crc,0);crc=crc_byte(crc,mask);
  send_byte(8'ha5);send_byte(8'h5a);send_byte(8'h01);send_byte(8'h01);send_byte(8'h00);send_byte(`CH4_MSG_STREAM_CONFIG);send_byte(`CH4_FLAG_ACK_REQUIRED);send_byte(seq[7:0]);send_byte(seq[15:8]);send_byte(1);send_byte(0);send_byte(mask);send_byte(crc[7:0]);send_byte(crc[15:8]);end endtask
 initial begin repeat(8)@(posedge clk);rst_n=1;repeat(8)@(posedge clk);
  send_empty_frame(`CH4_MSG_HELLO,1);wait(responses==1);
  send_stream_config(8'h01,2);wait(responses==2);
  send_empty_frame(`CH4_MSG_START_SCAN,3);wait(responses==3);
  send_empty_frame(`CH4_MSG_START_ACQUISITION,4);wait(responses==4);
  send_empty_frame(`CH4_MSG_STREAM_START,5);wait(responses==5);
  wait(angle_frames>=1);if(harmonic_frames!=0||data_frames!=0)$fatal(1,"angle-only mode emitted an unexpected stream");
  send_stream_config(8'h02,6);wait(responses==6);wait(harmonic_frames>=1);
  send_stream_config(8'h03,7);wait(responses==7);wait(data_frames>=1);
  $display("FPGA_UART_COMM_TEST_PASS responses=%0d angle=%0d harmonic=%0d fused=%0d",responses,angle_frames,harmonic_frames,data_frames);$finish;end
 initial begin #20_000_000;$fatal(1,"UART communication test timeout");end
endmodule
