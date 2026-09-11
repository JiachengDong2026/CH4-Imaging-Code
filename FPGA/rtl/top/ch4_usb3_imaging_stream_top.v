`timescale 1ns / 1ps
`include "protocol_defs.vh"

module ch4_usb3_imaging_stream_top #(
 parameter integer GAS_VARIATION = 0,
 parameter integer HARMONIC_ONLY = 0
)(
 input wire Clk_50M_In,Resetn, input wire HRACT,HRCLK,HRVLD,HTRDY,Rx_Ctrl,Tx_Ctrl,
 input wire uart_rxd, output wire uart_txd,
 output wire Bitstream_Done,HTACK,HTCLK,HTREQ,HTVLD,led, inout wire[31:0]HD);
 wire clk120m,clk30m,locked;reg[1:0]div;
 assign Bitstream_Done=locked;assign led=locked;assign HTACK=1'b0;
 clk_wiz_0 cw(.clk_out1(clk120m),.reset(~Resetn),.locked(locked),.clk_in1(Clk_50M_In));
 always @(posedge clk120m or negedge locked)if(!locked)div<=0;else div<=div+1'b1;
 BUFG cb(.I(div[1]),.O(clk30m));

 wire[63:0]control_ticks;system_timebase control_timebase(.clk(Clk_50M_In),.rst(!locked),.ticks(control_ticks));
 wire rxv,rxf;wire[7:0]rxb;uart_rx #(.CLK_HZ(50_000_000),.BAUD(921600))ur(
  .clk(Clk_50M_In),.rst(!locked),.rx(uart_rxd),.valid(rxv),.data(rxb),.framing_error(rxf));
 wire framev,frameerr,crcerr,lenerr,vererr,payloadv;wire[11:0]payload_index;wire[7:0]payload_data;
 wire[7:0]version,dst,src,msg_type,msg_flags;wire[15:0]sequence,payload_length;
 app_frame_rx parser(.clk(Clk_50M_In),.rst(!locked),.byte_valid(rxv),.byte_data(rxb),
  .payload_valid(payloadv),.payload_index(payload_index),.payload_data(payload_data),
  .frame_valid(framev),.frame_error(frameerr),.crc_error(crcerr),.length_error(lenerr),.version_error(vererr),
  .frame_version(version),.frame_dst(dst),.frame_src(src),.frame_type(msg_type),.frame_flags(msg_flags),
  .frame_sequence(sequence),.frame_payload_length(payload_length));
 wire response_pending,response_accept;wire[7:0]response_type;wire[15:0]response_seq;wire[135:0]response_payload;
 wire[31:0]accepted_frames,launched_frames,dropped_frames;
 wire scan_enable,scan_start_strobe,acq_enable,stream_enable,stream_angle_enable,stream_harmonic_enable;
 wire[15:0]config_revision,image_lines,mirror_feedback_hz;wire[31:0]stream_rate_hz,mirror_x_freq_mhz,mirror_frame_freq_mhz;
 wire signed[15:0]x_min,x_max,y_min,y_max,static_x,static_y;wire scan_policy;wire[1:0]stop_action;
 stage1_command_engine commands(.clk(Clk_50M_In),.rst(!locked),.frame_valid(framev&&(dst==8'h01||dst==8'hff)),.frame_type(msg_type),.frame_sequence(sequence),
  .payload_length(payload_length),.payload_valid(payloadv),.payload_index(payload_index),.payload_data(payload_data),.safe_boundary(1'b1),.scan_finished(1'b0),
  .system_ticks(control_ticks),.dropped_points(dropped_frames),.dsp_overflow(1'b0),.response_accept(response_accept),.response_pending(response_pending),
  .response_type(response_type),.response_sequence(response_seq),.response_payload(response_payload),.scan_enable(scan_enable),.scan_start_strobe(scan_start_strobe),
  .acquisition_enable(acq_enable),.stream_enable(stream_enable),.stream_angle_enable(stream_angle_enable),.stream_harmonic_enable(stream_harmonic_enable),.config_revision(config_revision),
  .x_min_q13(x_min),.x_max_q13(x_max),.y_min_q13(y_min),.y_max_q13(y_max),.image_lines(image_lines),.stream_rate_hz(stream_rate_hz),
  .mirror_x_freq_mhz(mirror_x_freq_mhz),.mirror_frame_freq_mhz(mirror_frame_freq_mhz),.mirror_feedback_hz(mirror_feedback_hz),
  .scan_policy(scan_policy),.stop_action(stop_action),.static_x_q13(static_x),.static_y_q13(static_y));
 wire resp_start,resp_busy,resp_bytev,resp_done,uart_busy,uart_done;wire[7:0]resp_byte;
 assign resp_start=response_pending&&!resp_busy&&!uart_busy;assign response_accept=resp_start;
 app_frame_serializer #(.PAYLOAD_BYTES(17))respser(.clk(Clk_50M_In),.rst(!locked),.start(resp_start),.dst(8'h00),.src(8'h01),
  .msg_type(response_type),.flags(`CH4_FLAG_IS_RESPONSE),.sequence(response_seq),.payload(response_payload),
  .byte_ready(!uart_busy),.byte_valid(resp_bytev),.byte_data(resp_byte),.busy(resp_busy),.done(resp_done));
 uart_tx #(.CLK_HZ(50_000_000),.BAUD(921600))ut(.clk(Clk_50M_In),.rst(!locked),.start(resp_bytev),
  .data(resp_byte),.tx(uart_txd),.busy(uart_busy),.done(uart_done));

 wire fused_valid;wire[383:0]fused_payload;wire curve_valid;wire[223:0]curve_payload;
 ch4_real_fused_point_source #(.GAS_VARIATION(GAS_VARIATION)) real_source(.clk(Clk_50M_In),.rst(!locked),.curve_rate_hz(stream_rate_hz),
  .fused_valid(fused_valid),.fused_payload(fused_payload),
  .curve_valid(curve_valid),.curve_payload(curve_payload));
 reg tx1,tx2;always @(posedge clk120m or negedge locked)if(!locked)begin tx1<=0;tx2<=0;end else begin tx1<=Tx_Ctrl;tx2<=tx1;end
 wire source_valid,source_last,source_ready,source_done,source_busy;wire[31:0]source_data;
 generate if (HARMONIC_ONLY != 0) begin : harmonic_stream
  usb_harmonic_stream_bridge bridge(.curve_clk(Clk_50M_In),.curve_rst(!locked),.stream_enabled(acq_enable&&stream_enable&&stream_harmonic_enable),
   .curve_valid(curve_valid),.curve_payload(curve_payload),.curve_ready(),
   .usb_clk(clk120m),.usb_rst(!locked),.transmit_request(tx2),
   .word_valid(source_valid),.word_data(source_data),.word_last(source_last),
   .word_ready(source_ready),.busy(source_busy),.block_done(source_done),.frame_too_long(),
   .accepted_frames(accepted_frames),.launched_frames(launched_frames),.dropped_frames(dropped_frames));
 end else begin : fused_stream
  usb_fused_point_stream_bridge bridge(.fused_clk(Clk_50M_In),.fused_rst(!locked),
   .fused_valid(fused_valid),.fused_payload(fused_payload),.fused_ready(),
   .usb_clk(clk120m),.usb_rst(!locked),.transmit_request(tx2),
   .word_valid(source_valid),.word_data(source_data),.word_last(source_last),
   .word_ready(source_ready),.busy(source_busy),.block_done(source_done),.frame_too_long(),
   .accepted_frames(accepted_frames),.launched_frames(launched_frames),.dropped_frames(dropped_frames));
 end endgenerate

 // Preserve the prefetch alignment proven by the golden stream image.
 reg[31:0]previous_word;reg previous_valid;wire fifo_full;
 wire[31:0]fifo_in=previous_valid?previous_word:source_data;
 assign source_ready=!fifo_full;
 always @(posedge clk120m or negedge locked)if(!locked)begin previous_word<=0;previous_valid<=0;end
  else if(source_done)begin previous_word<=0;previous_valid<=0;end
  else if(source_valid&&source_ready)begin previous_word<=source_data;previous_valid<=1;end
 wire fifo_empty,vendor_rd,fifo_rd;wire[31:0]fifo_out;
 fifo_generator_0 sf(.rst(!locked),.wr_clk(clk120m),.rd_clk(clk30m),.din(fifo_in),
  .wr_en(source_valid&&source_ready),.rd_en(fifo_rd),.dout(fifo_out),.full(fifo_full),
  .empty(fifo_empty),.wr_rst_busy(),.rd_rst_busy());
 reg block_ready;
 always @(posedge clk120m or negedge locked)if(!locked)block_ready<=0;
  else if(source_done)block_ready<=1;else if(!tx2)block_ready<=0;
 reg br1,br2,br3,prefetch;reg[1:0]delay_count;reg tx_enable;
 assign fifo_rd=prefetch||vendor_rd;
 always @(posedge clk30m or negedge locked)if(!locked)begin br1<=0;br2<=0;br3<=0;prefetch<=0;delay_count<=0;tx_enable<=0;end else begin
  br1<=block_ready;br2<=br1;br3<=br2;prefetch<=0;tx_enable<=0;
  if(br2&&!br3)begin prefetch<=1;delay_count<=2;end
  else if(delay_count!=0)begin delay_count<=delay_count-1'b1;if(delay_count==1)tx_enable<=1;end
 end
 wire[31:0]tx_data;
 HSPI_Tx transmitter(.Clk(clk30m),.Rst_n(locked),.Tx_En(tx_enable),.FIFO_EMPTY(fifo_empty),
  .FIFO_DOUT(fifo_out),.FIFO_RD_EN(vendor_rd),.HTCLK(HTCLK),.HTREQ(HTREQ),
  .HTRDY(HTRDY),.HTVLD(HTVLD),.HTD(tx_data));
 genvar i;generate for(i=0;i<32;i=i+1)begin:io IOBUF b(.O(),.IO(HD[i]),.I(tx_data[i]),.T(!(HTREQ&&!HRACT)));end endgenerate
 (* KEEP="TRUE",MARK_DEBUG="TRUE" *) wire[31:0]usb_stream_debug={
  dropped_frames[1:0],launched_frames[3:0],accepted_frames[3:0],
  2'b00,source_busy,previous_valid,fifo_full,fifo_empty,block_ready,
  tx_enable,prefetch,vendor_rd,HTRDY,HTVLD,HTREQ,tx2,tx1,Tx_Ctrl,
  source_done,source_last,source_ready,source_valid,fused_valid,locked};
 wire unused=HRCLK^HRVLD^Rx_Ctrl^source_last^source_busy^accepted_frames[0]^launched_frames[0]^dropped_frames[0];
endmodule
