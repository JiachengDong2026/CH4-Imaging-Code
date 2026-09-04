`include "protocol_defs.vh"

// Hardware-safe UART integration image for testing independent stream modes.
module ch4_uart_comm_test_top #(parameter integer CLOCK_HZ=50_000_000,UART_BAUD=921600)(
 input wire sys_clk,input wire sys_rst_n,input wire uart_rxd,output wire uart_txd);
 wire rst;wire[63:0]ticks;reset_sync rs(.clk(sys_clk),.arst_n(sys_rst_n),.srst(rst));
 system_timebase timebase(.clk(sys_clk),.rst(rst),.ticks(ticks));
 wire rxv,rxf;wire[7:0]rxb;uart_rx #(.CLK_HZ(CLOCK_HZ),.BAUD(UART_BAUD))rx(.clk(sys_clk),.rst(rst),.rx(uart_rxd),.valid(rxv),.data(rxb),.framing_error(rxf));
 wire framev,frameerr,crcerr,lenerr,vererr,payloadv;wire[11:0]payload_index;wire[7:0]payload_data;wire[7:0]version,dst,src,msg_type,msg_flags;wire[15:0]sequence,payload_length;
 app_frame_rx parser(.clk(sys_clk),.rst(rst),.byte_valid(rxv),.byte_data(rxb),.payload_valid(payloadv),.payload_index(payload_index),.payload_data(payload_data),.frame_valid(framev),.frame_error(frameerr),.crc_error(crcerr),.length_error(lenerr),.version_error(vererr),.frame_version(version),.frame_dst(dst),.frame_src(src),.frame_type(msg_type),.frame_flags(msg_flags),.frame_sequence(sequence),.frame_payload_length(payload_length));

 wire scan_enable,acq_enable,stream_enable,stream_angle_enable,stream_harmonic_enable;wire[15:0]config_revision,image_lines;wire signed[15:0]x_min,x_max,y_min,y_max;wire[31:0]stream_rate_hz;
 wire response_pending,response_accept;wire[7:0]response_type;wire[15:0]response_seq;wire[135:0]response_payload;
 reg[16:0]point_div;reg point_tick;
 always @(posedge sys_clk)if(rst||!scan_enable||!acq_enable||!stream_enable)begin point_div<=0;point_tick<=0;end else begin point_tick<=0;if(point_div==17'd99999)begin point_div<=0;point_tick<=1;end else point_div<=point_div+1'b1;end
 reg[5:0]column;reg[6:0]line;reg[31:0]image_id;reg reverse;reg signed[15:0]x_angle,y_angle;
 always @(posedge sys_clk)if(rst||!scan_enable)begin column<=0;line<=0;image_id<=0;reverse<=0;x_angle<=-16'sd16384;y_angle<=-16'sd8192;end else if(point_tick)begin
  if(column==6'd49)begin column<=0;if(line>=7'd63)begin line<=0;image_id<=image_id+1'b1;reverse<=0;x_angle<=-16'sd16384;y_angle<=-16'sd8192;end else begin line<=line+1'b1;reverse<=~reverse;if(line==7'd62)y_angle<=16'sd8192;else y_angle<=y_angle+16'sd260;end end
  else begin column<=column+1'b1;if(column==6'd48)x_angle<=reverse?-16'sd16384:16'sd16384;else x_angle<=reverse?(x_angle-16'sd668):(x_angle+16'sd668);end
 end
 wire[31:0]a1=32'd200000;wire[31:0]a2=32'd2000+({26'd0,column}*32'd180)+({25'd0,line}*32'd35);wire[15:0]quality_flags=16'h00D8|(reverse?16'h0001:16'h0000);wire[383:0]fused_payload;
 fused_point_builder pack(.measurement_time(ticks),.image_id(image_id),.line_id({9'd0,line}),.point_id({10'd0,column}),.x_angle(x_angle),.y_angle(y_angle),.i1(32'sd180000),.q1(32'sd20000),.i2($signed(a2)),.q2($signed(a2>>>1)),.a1(a1),.a2(a2),.flags(quality_flags),.config_revision(config_revision),.payload(fused_payload));
 reg measure_pending,angle_pending,harmonic_pending;reg[383:0]measure_payload;reg[127:0]angle_payload;reg[223:0]harmonic_payload;reg[15:0]measure_seq,angle_seq,harmonic_seq;reg[31:0]dropped_points;
 wire resp_start,resp_busy,resp_bytev,resp_done;wire[7:0]resp_byte;wire measure_start,measure_busy,measure_bytev,measure_done;wire[7:0]measure_byte;wire angle_start,angle_busy,angle_bytev,angle_done;wire[7:0]angle_byte;wire harmonic_start,harmonic_busy,harmonic_bytev,harmonic_done;wire[7:0]harmonic_byte;wire uart_busy,uart_done;
 assign resp_start=response_pending&&!resp_busy&&!angle_busy&&!measure_busy&&!harmonic_busy&&!uart_busy;assign response_accept=resp_start;
 assign angle_start=angle_pending&&!angle_busy&&!resp_busy&&!response_pending&&!measure_busy&&!harmonic_busy&&!uart_busy;
 assign harmonic_start=harmonic_pending&&!harmonic_busy&&!resp_busy&&!response_pending&&!angle_busy&&!measure_busy&&!uart_busy;
 assign measure_start=measure_pending&&!measure_busy&&!angle_busy&&!harmonic_busy&&!resp_busy&&!response_pending&&!angle_pending&&!harmonic_pending&&!uart_busy;
 always @(posedge sys_clk)if(rst)begin measure_pending<=0;angle_pending<=0;harmonic_pending<=0;measure_payload<=0;angle_payload<=0;harmonic_payload<=0;measure_seq<=0;angle_seq<=0;harmonic_seq<=0;dropped_points<=0;end else begin
  if(measure_start)begin measure_pending<=0;measure_seq<=measure_seq+1'b1;end
  if(angle_start)begin angle_pending<=0;angle_seq<=angle_seq+1'b1;end
  if(harmonic_start)begin harmonic_pending<=0;harmonic_seq<=harmonic_seq+1'b1;end
  if(point_tick&&stream_angle_enable&&stream_harmonic_enable)begin if(!measure_pending||measure_start)begin measure_payload<=fused_payload;measure_pending<=1;end else dropped_points<=dropped_points+1'b1;end
  if(point_tick&&stream_angle_enable&&(!angle_pending||angle_start))begin angle_payload<={y_angle,x_angle,{16'd0,line},ticks};angle_pending<=1;end
  if(point_tick&&stream_harmonic_enable&&(!harmonic_pending||harmonic_start))begin harmonic_payload<={a2>>>1,a2,32'sd20000,32'sd180000,{16'd0,column},ticks};harmonic_pending<=1;end
 end
 stage1_command_engine commands(.clk(sys_clk),.rst(rst),.frame_valid(framev&&(dst==8'h01||dst==8'hff)),.frame_type(msg_type),.frame_sequence(sequence),.payload_length(payload_length),.payload_valid(payloadv),.payload_index(payload_index),.payload_data(payload_data),.safe_boundary(point_tick||!acq_enable),.scan_finished(1'b0),.system_ticks(ticks),.dropped_points(dropped_points),.dsp_overflow(1'b0),.response_accept(response_accept),.response_pending(response_pending),.response_type(response_type),.response_sequence(response_seq),.response_payload(response_payload),.scan_enable(scan_enable),.acquisition_enable(acq_enable),.stream_enable(stream_enable),.stream_angle_enable(stream_angle_enable),.stream_harmonic_enable(stream_harmonic_enable),.config_revision(config_revision),.x_min_q13(x_min),.x_max_q13(x_max),.y_min_q13(y_min),.y_max_q13(y_max),.image_lines(image_lines),.stream_rate_hz(stream_rate_hz));
 app_frame_serializer #(.PAYLOAD_BYTES(17))respser(.clk(sys_clk),.rst(rst),.start(resp_start),.dst(8'h00),.src(8'h01),.msg_type(response_type),.flags(`CH4_FLAG_IS_RESPONSE),.sequence(response_seq),.payload(response_payload),.byte_ready(!uart_busy&&!resp_bytev),.byte_valid(resp_bytev),.byte_data(resp_byte),.busy(resp_busy),.done(resp_done));
 app_frame_serializer #(.PAYLOAD_BYTES(16))angleser(.clk(sys_clk),.rst(rst),.start(angle_start),.dst(8'h00),.src(8'h01),.msg_type(`CH4_MSG_ANGLE_SAMPLE),.flags(`CH4_FLAG_DATA_VALID),.sequence(angle_seq),.payload(angle_payload),.byte_ready(!uart_busy&&!resp_bytev&&!angle_bytev&&!harmonic_bytev&&!measure_bytev),.byte_valid(angle_bytev),.byte_data(angle_byte),.busy(angle_busy),.done(angle_done));
 app_frame_serializer #(.PAYLOAD_BYTES(28))harmonicser(.clk(sys_clk),.rst(rst),.start(harmonic_start),.dst(8'h00),.src(8'h01),.msg_type(`CH4_MSG_HARMONIC_CURVE),.flags(`CH4_FLAG_DATA_VALID),.sequence(harmonic_seq),.payload(harmonic_payload),.byte_ready(!uart_busy&&!resp_bytev&&!angle_bytev&&!harmonic_bytev&&!measure_bytev),.byte_valid(harmonic_bytev),.byte_data(harmonic_byte),.busy(harmonic_busy),.done(harmonic_done));
 app_frame_serializer #(.PAYLOAD_BYTES(48))dataser(.clk(sys_clk),.rst(rst),.start(measure_start),.dst(8'h00),.src(8'h01),.msg_type(`CH4_MSG_FUSED_POINT),.flags(`CH4_FLAG_DATA_VALID),.sequence(measure_seq),.payload(measure_payload),.byte_ready(!uart_busy&&!resp_bytev&&!angle_bytev&&!harmonic_bytev&&!measure_bytev),.byte_valid(measure_bytev),.byte_data(measure_byte),.busy(measure_busy),.done(measure_done));
 uart_tx #(.CLK_HZ(CLOCK_HZ),.BAUD(UART_BAUD))tx(.clk(sys_clk),.rst(rst),.start(resp_bytev|angle_bytev|harmonic_bytev|measure_bytev),.data(resp_bytev?resp_byte:(angle_bytev?angle_byte:(harmonic_bytev?harmonic_byte:measure_byte))),.tx(uart_txd),.busy(uart_busy),.done(uart_done));
endmodule
