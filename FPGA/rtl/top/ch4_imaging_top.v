`include "protocol_defs.vh"

module ch4_imaging_top #(parameter integer CLOCK_HZ=50_000_000,UART_BAUD=921600)(
 input wire sys_clk,input wire sys_rst_n,input wire uart_rxd,output wire uart_txd,
 input wire mirror_rxd_p,mirror_rxd_n,output wire mirror_txd_p,mirror_txd_n);
 wire rst;wire[63:0]ticks;reset_sync rs(.clk(sys_clk),.arst_n(sys_rst_n),.srst(rst));
 system_timebase tb(.clk(sys_clk),.rst(rst),.ticks(ticks));

 wire rxv,rxf;wire[7:0]rxb;uart_rx #(.CLK_HZ(CLOCK_HZ),.BAUD(UART_BAUD))ur(
  .clk(sys_clk),.rst(rst),.rx(uart_rxd),.valid(rxv),.data(rxb),.framing_error(rxf));
 wire framev,frameerr,crcerr,lenerr,vererr,payloadv;wire[11:0]payload_index;wire[7:0]payload_data;
 wire[7:0]version,dst,src,msg_type,msg_flags;wire[15:0]sequence,payload_length;
 app_frame_rx parser(.clk(sys_clk),.rst(rst),.byte_valid(rxv),.byte_data(rxb),
  .payload_valid(payloadv),.payload_index(payload_index),.payload_data(payload_data),
  .frame_valid(framev),.frame_error(frameerr),.crc_error(crcerr),.length_error(lenerr),.version_error(vererr),
  .frame_version(version),.frame_dst(dst),.frame_src(src),.frame_type(msg_type),.frame_flags(msg_flags),
  .frame_sequence(sequence),.frame_payload_length(payload_length));

 // The committed HITRAN ROM is replayed at its original 25.6 MSPS rate.
 wire sample_tick;fractional_sample_tick #(.CLOCK_HZ(CLOCK_HZ),.SAMPLE_HZ(25_600_000)) st(
  .clk(sys_clk),.rst(rst),.tick(sample_tick));
 wire romv,rom_start,rom_end;wire signed[15:0]rom_sample;wire[13:0]rom_index;
 ch4_rom_source #(.DEPTH(12800))rom(
  .clk(sys_clk),.rst(rst),.enable(1'b1),.advance(sample_tick),.valid(romv),.scan_start(rom_start),
  .scan_end(rom_end),.sample(rom_sample),.index(rom_index));
 wire calv,saturated;wire signed[15:0]cal_sample;adc_calibration cal(.clk(sys_clk),.rst(rst),.in_valid(romv),
  .in_sample(rom_sample),.offset(32'sd0),.gain_q16(32'sd65536),.out_valid(calv),.out_sample(cal_sample),.saturated(saturated));
 reg signed[15:0]sample_aligned;always @(posedge sys_clk)if(rst)sample_aligned<=0;else if(calv)sample_aligned<=cal_sample;
 wire ncov;wire signed[17:0]sin1,cos1,sin2,cos2;nco refnco(.clk(sys_clk),.rst(rst),.enable(calv),.phase_reset(1'b0),
  .phase_inc(32'h02000000),.phase_offset_1f(32'd0),.phase_offset_2f(32'h80000000),.valid(ncov),
  .sin_1f(sin1),.cos_1f(cos1),.sin_2f(sin2),.cos_2f(cos2));
 wire dilav,dila_overflow;wire signed[31:0]di1,dq1,di2,dq2;wire[32:0]unused_a1,unused_a2;
 demod_chain dila(.clk(sys_clk),.rst(rst),.clear(1'b0),.in_valid(ncov),.sample(sample_aligned),
  .sin1(sin1),.cos1(cos1),.sin2(sin2),.cos2(cos2),.cic_decim(13'd8),.tap_count(5'd16),.fir_decim(5'd1),
  .active_bank(1'b0),.coeff_we(1'b0),.coeff_bank(1'b0),.coeff_addr(5'd0),.coeff_wdata(18'sd0),
  .out_valid(dilav),.i1(di1),.q1(dq1),.i2(di2),.q2(dq2),.a1(unused_a1),.a2(unused_a2),.overflow(dila_overflow));
 wire smoothv;wire signed[31:0]si1,sq1,si2,sq2;iq_boxcar16 smooth(.clk(sys_clk),.rst(rst),.clear(1'b0),
  .in_valid(dilav),.i1(di1),.q1(dq1),.i2(di2),.q2(dq2),.out_valid(smoothv),.oi1(si1),.oq1(sq1),.oi2(si2),.oq2(sq2));
 wire pointv,scan_start,scan_end;wire[31:0]point_index;wire signed[31:0]fi1,fq1,fi2,fq2;
 // CIC /8 leaves 1,600 demodulated samples in every 12,800-sample HITRAN
 // wavelength sweep.  iq_boxcar16 is a sliding smoother, so it preserves
 // that point rate rather than reducing it by another factor of sixteen.
 scan_framer framer(.clk(sys_clk),.rst(rst),.enable(1'b1),.in_valid(smoothv),.scan_points(32'd1600),.master_tick(ticks),
  .i1(si1),.q1(sq1),.i2(si2),.q2(sq2),.point_valid(pointv),.scan_start(scan_start),.scan_end(scan_end),
  .point_index(point_index),.out_i1(fi1),.out_q1(fq1),.out_i2(fi2),.out_q2(fq2));

 wire scan_enable,scan_start_strobe,acq_enable,stream_enable,stream_angle_enable,stream_harmonic_enable,scan_policy,scan_stream_active;wire[15:0]config_revision,image_lines,mirror_feedback_hz;wire[1:0]stop_action;
 wire signed[15:0]x_min,x_max,y_min,y_max,static_x,static_y;wire[31:0]stream_rate_hz,mirror_x_freq_mhz,mirror_frame_freq_mhz;
 wire featurev;wire[63:0]feature_time;wire signed[31:0]feature_i1,feature_q1,feature_i2,feature_q2;
 wire[31:0]feature_a1,feature_a2;wire[15:0]feature_flags;
 wms_feature_extractor feature(.clk(sys_clk),.rst(rst),.enable(acq_enable),.point_valid(pointv),.scan_start(scan_start),.scan_end(scan_end),
  .point_index(point_index),.master_tick(ticks),.i1(fi1),.q1(fq1),.i2(fi2),.q2(fq2),.roi_start(32'd160),.roi_end(32'd1440),
  .overflow(dila_overflow),.saturated(saturated),.result_valid(featurev),.result_time(feature_time),
  .result_i1(feature_i1),.result_q1(feature_q1),.result_i2(feature_i2),.result_q2(feature_q2),
  .result_a1(feature_a1),.result_a2(feature_a2),.quality_flags(feature_flags));

 // The feature engine produces 2 kHz.  A fractional scheduler preserves the
 // requested rate (1..2000 Hz) instead of coarsely quantizing it to 500 Hz.
 // With only the 16-byte angle frame enabled, 2 kHz is about 580 kbps at the
 // configured 921600-baud application UART.
 reg[11:0]rate_phase;reg select_feature;wire[11:0]effective_stream_rate=(stream_rate_hz>32'd2000)?12'd2000:stream_rate_hz[11:0];
 wire[12:0]rate_sum={1'b0,rate_phase}+effective_stream_rate;
 always @(posedge sys_clk)if(rst||!acq_enable)begin rate_phase<=0;select_feature<=0;end else begin select_feature<=0;
  if(featurev)if(rate_sum>=13'd2000)begin rate_phase<=rate_sum-13'd2000;select_feature<=stream_enable&&scan_stream_active&&(stream_angle_enable||stream_harmonic_enable);end else rate_phase<=rate_sum[11:0];end
 reg[63:0]held_time;reg signed[31:0]held_i1,held_q1,held_i2,held_q2;reg[31:0]held_a1,held_a2;reg[15:0]held_flags;
 always @(posedge sys_clk)if(select_feature)begin held_time<=feature_time;held_i1<=feature_i1;held_q1<=feature_q1;held_i2<=feature_i2;held_q2<=feature_q2;
  held_a1<=feature_a1;held_a2<=feature_a2;held_flags<=feature_flags;end
 wire mirror_rx_single,mirror_tx_single,mirror_feedback_valid,mirror_scan_finished;wire signed[15:0]mirror_feedback_x,mirror_feedback_y;wire[31:0]mirror_feedback_errors;
 IBUFDS mirror_rx_buffer(.I(mirror_rxd_p),.IB(mirror_rxd_n),.O(mirror_rx_single));
 OBUFDS mirror_tx_buffer(.I(mirror_tx_single),.O(mirror_txd_p),.OB(mirror_txd_n));
 fast_mirror_link mirror_link(.clk(sys_clk),.rst(rst),.scan_enable(scan_enable),.scan_start(scan_start_strobe),.x_min(x_min),.x_max(x_max),.y_min(y_min),.y_max(y_max),.static_x(static_x),.static_y(static_y),.x_frequency_mhz(mirror_x_freq_mhz),.frame_frequency_mhz(mirror_frame_freq_mhz),.scan_policy(scan_policy),.feedback_hz(mirror_feedback_hz),.mirror_rx(mirror_rx_single),.mirror_tx(mirror_tx_single),.feedback_valid(mirror_feedback_valid),.feedback_x(mirror_feedback_x),.feedback_y(mirror_feedback_y),.feedback_errors(mirror_feedback_errors),.scan_finished(mirror_scan_finished));
 assign scan_stream_active=scan_enable&&!mirror_scan_finished;
 reg[25:0]mirror_feedback_age;reg[2:0]mirror_valid_streak;
 always @(posedge sys_clk)if(rst)begin mirror_feedback_age<=26'd25_000_000;mirror_valid_streak<=0;end else begin
  if(mirror_feedback_valid)begin mirror_feedback_age<=0;if(mirror_valid_streak<3'd7)mirror_valid_streak<=mirror_valid_streak+1'b1;end
  else begin if(mirror_feedback_age<26'd25_000_000)mirror_feedback_age<=mirror_feedback_age+1'b1;if(mirror_feedback_age>=26'd25_000_000)mirror_valid_streak<=0;end
 end
 wire mirror_feedback_active=(mirror_valid_streak>=3'd3)&&(mirror_feedback_age<26'd25_000_000);
 wire signed[15:0]actual_x=mirror_feedback_active?mirror_feedback_x:16'sd0;
 wire signed[15:0]actual_y=mirror_feedback_active?mirror_feedback_y:16'sd0;
 reg[31:0]image_id;reg[15:0]line_id,point_id;reg reverse,line_event;
 always @(posedge sys_clk)if(rst||!scan_stream_active)begin image_id<=0;line_id<=0;point_id<=0;reverse<=0;line_event<=0;end else if(select_feature)begin
  line_event<=0;
  if(point_id==16'd49)begin point_id<=0;line_event<=1;
   if(line_id>=image_lines-1'b1)begin line_id<=0;image_id<=image_id+1'b1;reverse<=0;end
   else begin line_id<=line_id+1'b1;reverse<=~reverse;end
  end else point_id<=point_id+1'b1;
 end
 reg emit_point,emit_angle;always @(posedge sys_clk)if(rst)begin emit_point<=0;emit_angle<=0;end else begin
  emit_point<=select_feature&&mirror_feedback_active&&stream_angle_enable&&stream_harmonic_enable;
  emit_angle<=select_feature&&mirror_feedback_active&&stream_angle_enable;
 end
  wire[15:0]fused_flags=held_flags|(reverse?16'h0001:0)|(line_event?16'h0004:0)|(mirror_feedback_active?16'h0010:16'h0400);
 wire[383:0]fused_payload;fused_point_builder pack(.measurement_time(held_time),.image_id(image_id),.line_id(line_id),.point_id(point_id),
  .x_angle(actual_x),.y_angle(actual_y),.i1(held_i1),.q1(held_q1),.i2(held_i2),.q2(held_q2),.a1(held_a1),.a2(held_a2),
  .flags(fused_flags),.config_revision(config_revision),.payload(fused_payload));

 // UART cannot carry all 100 bins from every 2 kHz wavelength sweep.  Send
 // one rotating, uniformly spaced bin every second sweep instead: the host
 // receives a complete, correctly ordered 100-point 1f/2f curve every 100 ms
 // without smearing bins from different wavelength positions together.
 reg curve_sweep;reg[6:0]curve_bin,curve_sample_bin;reg signed[31:0]curve_sample_i1,curve_sample_q1,curve_sample_i2,curve_sample_q2;reg curve_sample_valid;
 wire curve_sample=pointv&&curve_sweep&&(point_index==({25'd0,curve_bin}<<4));
 always @(posedge sys_clk)if(rst||!acq_enable)begin curve_sweep<=0;curve_bin<=0;curve_sample_bin<=0;curve_sample_i1<=0;curve_sample_q1<=0;curve_sample_i2<=0;curve_sample_q2<=0;curve_sample_valid<=0;end else begin
  curve_sample_valid<=curve_sample;
  if(curve_sample)begin curve_sample_bin<=curve_bin;curve_sample_i1<=fi1;curve_sample_q1<=fq1;curve_sample_i2<=fi2;curve_sample_q2<=fq2;end
  if(pointv&&scan_end)begin
   curve_sweep<=~curve_sweep;
   if(curve_sweep)begin if(curve_bin==7'd99)curve_bin<=0;else curve_bin<=curve_bin+1'b1;end
  end
 end

 reg measure_pending;reg[383:0]measure_payload;reg[31:0]dropped_points;reg[15:0]measure_seq;
 reg angle_pending;reg[127:0]angle_payload;reg[15:0]angle_seq;
 reg harmonic_pending;reg[223:0]harmonic_payload;reg[15:0]harmonic_seq;
 wire response_pending,response_accept;wire[7:0]response_type;wire[15:0]response_seq;wire[135:0]response_payload;
 wire resp_start,resp_busy,resp_bytev,resp_done;wire[7:0]resp_byte;
 wire measure_start,measure_busy,measure_bytev,measure_done;wire[7:0]measure_byte;
 wire angle_start,angle_busy,angle_bytev,angle_done;wire[7:0]angle_byte;
 wire harmonic_start,harmonic_busy,harmonic_bytev,harmonic_done;wire[7:0]harmonic_byte;wire uart_busy,uart_done;
 assign resp_start=response_pending&&!resp_busy&&!angle_busy&&!measure_busy&&!harmonic_busy&&!uart_busy;assign response_accept=resp_start;
 assign angle_start=angle_pending&&!angle_busy&&!resp_busy&&!response_pending&&!measure_busy&&!harmonic_busy&&!uart_busy;
 assign harmonic_start=harmonic_pending&&!harmonic_busy&&!resp_busy&&!response_pending&&!angle_busy&&!measure_busy&&!uart_busy;
 assign measure_start=measure_pending&&!measure_busy&&!angle_busy&&!harmonic_busy&&!resp_busy&&!response_pending&&!angle_pending&&!harmonic_pending&&!uart_busy;
 always @(posedge sys_clk)if(rst)begin measure_pending<=0;measure_payload<=0;dropped_points<=0;measure_seq<=0;angle_pending<=0;angle_payload<=0;angle_seq<=0;harmonic_pending<=0;harmonic_payload<=0;harmonic_seq<=0;end else begin
  if(measure_start)begin measure_pending<=0;measure_seq<=measure_seq+1'b1;end
  if(angle_start)begin angle_pending<=0;angle_seq<=angle_seq+1'b1;end
  if(harmonic_start)begin harmonic_pending<=0;harmonic_seq<=harmonic_seq+1'b1;end
  if(emit_point)begin if(!measure_pending||measure_start)begin measure_payload<=fused_payload;measure_pending<=1;end else dropped_points<=dropped_points+1'b1;end
  if(emit_angle&&(!angle_pending||angle_start))begin
   angle_payload<={actual_y,actual_x,{16'd0,line_id},ticks};angle_pending<=1;
  end
  if(curve_sample_valid&&stream_enable&&scan_stream_active&&stream_harmonic_enable&&(!harmonic_pending||harmonic_start))begin
   harmonic_payload<={curve_sample_q2,curve_sample_i2,curve_sample_q1,curve_sample_i1,{25'd0,curve_sample_bin},ticks};harmonic_pending<=1;
  end end
 stage1_command_engine commands(.clk(sys_clk),.rst(rst),.frame_valid(framev&&(dst==8'h01||dst==8'hff)),.frame_type(msg_type),.frame_sequence(sequence),
  .payload_length(payload_length),.payload_valid(payloadv),.payload_index(payload_index),.payload_data(payload_data),.safe_boundary(featurev||!acq_enable),.scan_finished(mirror_scan_finished),
  .system_ticks(ticks),.dropped_points(dropped_points),.dsp_overflow(dila_overflow),.response_accept(response_accept),.response_pending(response_pending),
  .response_type(response_type),.response_sequence(response_seq),.response_payload(response_payload),.scan_enable(scan_enable),.scan_start_strobe(scan_start_strobe),
  .acquisition_enable(acq_enable),.stream_enable(stream_enable),.stream_angle_enable(stream_angle_enable),.stream_harmonic_enable(stream_harmonic_enable),.config_revision(config_revision),
  .x_min_q13(x_min),.x_max_q13(x_max),.y_min_q13(y_min),.y_max_q13(y_max),.image_lines(image_lines),.stream_rate_hz(stream_rate_hz),.mirror_x_freq_mhz(mirror_x_freq_mhz),.mirror_frame_freq_mhz(mirror_frame_freq_mhz),.mirror_feedback_hz(mirror_feedback_hz),.scan_policy(scan_policy),.stop_action(stop_action),.static_x_q13(static_x),.static_y_q13(static_y));
 app_frame_serializer #(.PAYLOAD_BYTES(17))respser(.clk(sys_clk),.rst(rst),.start(resp_start),.dst(8'h00),.src(8'h01),
  .msg_type(response_type),.flags(`CH4_FLAG_IS_RESPONSE),.sequence(response_seq),.payload(response_payload),
  .byte_ready(!uart_busy&&!resp_bytev),.byte_valid(resp_bytev),.byte_data(resp_byte),.busy(resp_busy),.done(resp_done));
 app_frame_serializer #(.PAYLOAD_BYTES(16))angleser(.clk(sys_clk),.rst(rst),.start(angle_start),.dst(8'h00),.src(8'h01),
  .msg_type(`CH4_MSG_ANGLE_SAMPLE),.flags(`CH4_FLAG_DATA_VALID),.sequence(angle_seq),.payload(angle_payload),
  .byte_ready(!uart_busy&&!resp_bytev&&!angle_bytev&&!harmonic_bytev&&!measure_bytev),.byte_valid(angle_bytev),.byte_data(angle_byte),.busy(angle_busy),.done(angle_done));
 app_frame_serializer #(.PAYLOAD_BYTES(48))dataser(.clk(sys_clk),.rst(rst),.start(measure_start),.dst(8'h00),.src(8'h01),
  .msg_type(`CH4_MSG_FUSED_POINT),.flags(`CH4_FLAG_DATA_VALID),.sequence(measure_seq),.payload(measure_payload),
  .byte_ready(!uart_busy&&!resp_bytev&&!angle_bytev&&!harmonic_bytev&&!measure_bytev),.byte_valid(measure_bytev),.byte_data(measure_byte),.busy(measure_busy),.done(measure_done));
 app_frame_serializer #(.PAYLOAD_BYTES(28))harmonicser(.clk(sys_clk),.rst(rst),.start(harmonic_start),.dst(8'h00),.src(8'h01),
  .msg_type(`CH4_MSG_HARMONIC_CURVE),.flags(`CH4_FLAG_DATA_VALID),.sequence(harmonic_seq),.payload(harmonic_payload),
  .byte_ready(!uart_busy&&!resp_bytev&&!angle_bytev&&!harmonic_bytev&&!measure_bytev),.byte_valid(harmonic_bytev),.byte_data(harmonic_byte),.busy(harmonic_busy),.done(harmonic_done));
 uart_tx #(.CLK_HZ(CLOCK_HZ),.BAUD(UART_BAUD))ut(.clk(sys_clk),.rst(rst),.start(resp_bytev|angle_bytev|harmonic_bytev|measure_bytev),
  .data(resp_bytev?resp_byte:(angle_bytev?angle_byte:(harmonic_bytev?harmonic_byte:measure_byte))),.tx(uart_txd),.busy(uart_busy),.done(uart_done));
endmodule
