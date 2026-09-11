`include "protocol_defs.vh"

// Minimal but complete stage-1 command plane. Configuration writes go to a
// shadow bank and COMMIT_CONFIG applies all values at the next WMS boundary.
module stage1_command_engine(
 input wire clk,rst,frame_valid,input wire[7:0]frame_type,input wire[15:0]frame_sequence,input wire[15:0]payload_length,
 input wire payload_valid,input wire[11:0]payload_index,input wire[7:0]payload_data,input wire safe_boundary,scan_finished,
 input wire[63:0]system_ticks,input wire[31:0]dropped_points,input wire dsp_overflow,
 input wire response_accept,output reg response_pending,output reg[7:0]response_type,
 output reg[15:0]response_sequence,output reg[135:0]response_payload,
 output reg scan_enable,scan_start_strobe,acquisition_enable,stream_enable,stream_angle_enable,stream_harmonic_enable,output reg[15:0]config_revision,
 output reg signed[15:0]x_min_q13,x_max_q13,y_min_q13,y_max_q13,
 output reg[15:0]image_lines,output reg[31:0]stream_rate_hz,mirror_x_freq_mhz,mirror_frame_freq_mhz,output reg[15:0]mirror_feedback_hz,
 output reg scan_policy,output reg[1:0]stop_action,
 output reg signed[15:0]static_x_q13,static_y_q13);
 reg[7:0]payload[0:7];reg commit_pending,config_valid;
 reg signed[15:0]sx_min,sx_max,sy_min,sy_max;reg[15:0]s_lines,s_feedback_hz;reg[31:0]s_stream_rate,s_x_freq_mhz,s_frame_freq_mhz;reg s_scan_policy;reg[1:0]s_stop_action;
 integer k;reg[31:0]address,value,read_value;reg[7:0]status;

 task build_response;
  input[7:0]msg;input[15:0]seq;input[7:0]st;input[31:0]v0,v1,v2,v3;
  begin response_pending<=1;response_type<=msg;response_sequence<=seq;
   response_payload<={v3,v2,v1,v0,st};end
 endtask

 always @(posedge clk)begin
  if(rst)begin
   for(k=0;k<8;k=k+1)payload[k]<=0;response_pending<=0;response_type<=0;response_sequence<=0;response_payload<=0;
   scan_enable<=0;scan_start_strobe<=0;acquisition_enable<=0;stream_enable<=0;stream_angle_enable<=1;stream_harmonic_enable<=1;config_revision<=0;commit_pending<=0;config_valid<=1;
   sx_min<=-16'sd8192;sx_max<=16'sd8192;sy_min<=-16'sd8192;sy_max<=16'sd8192;s_lines<=75;s_stream_rate<=2000;s_x_freq_mhz<=15000;s_frame_freq_mhz<=400;s_feedback_hz<=2000;s_scan_policy<=1;s_stop_action<=0;
   x_min_q13<=-16'sd8192;x_max_q13<=16'sd8192;y_min_q13<=-16'sd8192;y_max_q13<=16'sd8192;image_lines<=75;stream_rate_hz<=2000;mirror_x_freq_mhz<=15000;mirror_frame_freq_mhz<=400;mirror_feedback_hz<=2000;scan_policy<=1;stop_action<=0;static_x_q13<=0;static_y_q13<=0;
  end else begin
   scan_start_strobe<=0;
   // A completed one-shot raster stops the signal-processing and host data
   // streams, while scan_enable stays asserted so the mirror holds its final
   // commanded endpoint instead of executing a stop-position move.
   if(scan_finished)begin acquisition_enable<=0;stream_enable<=0;end
   if(response_accept)response_pending<=0;
   if(payload_valid&&payload_index<8)payload[payload_index]<=payload_data;
   if(commit_pending&&safe_boundary)begin x_min_q13<=sx_min;x_max_q13<=sx_max;y_min_q13<=sy_min;y_max_q13<=sy_max;
    image_lines<=s_lines;stream_rate_hz<=s_stream_rate;mirror_x_freq_mhz<=s_x_freq_mhz;mirror_frame_freq_mhz<=s_frame_freq_mhz;mirror_feedback_hz<=s_feedback_hz;scan_policy<=s_scan_policy;stop_action<=s_stop_action;config_revision<=config_revision+1'b1;commit_pending<=0;end
   if(frame_valid&&!response_pending)begin
    address={payload[3],payload[2],payload[1],payload[0]};value={payload[7],payload[6],payload[5],payload[4]};status=`CH4_STATUS_OK;read_value=0;
    case(frame_type)
     `CH4_MSG_HELLO:build_response(frame_type,frame_sequence,status,32'h49344843,32'h00010000,32'd50_000_000,32'h000000FB);
     `CH4_MSG_HEARTBEAT:build_response(frame_type,frame_sequence,status,system_ticks[31:0],system_ticks[63:32],0,0);
     `CH4_MSG_READ_REG:begin
      if(payload_length!=4)status=`CH4_STATUS_BAD_LENGTH;else case(address[15:0])
       `CH4_REG_DEVICE_ID:read_value=32'h49344843;`CH4_REG_FW_VERSION:read_value=32'h00010000;
       `CH4_REG_PROTOCOL_VERSION:read_value=1;`CH4_REG_CAPABILITY_FLAGS:read_value=32'h000000FB;
       `CH4_REG_SYSTEM_STATUS:read_value={27'd0,dsp_overflow,stream_enable,acquisition_enable,scan_enable,1'b1};
       `CH4_REG_CONFIG_REVISION:read_value={16'd0,config_revision};`CH4_REG_TIME_LOW:read_value=system_ticks[31:0];`CH4_REG_TIME_HIGH:read_value=system_ticks[63:32];
       `CH4_REG_MIRROR_X_MIN_Q13:read_value={{16{x_min_q13[15]}},x_min_q13};`CH4_REG_MIRROR_X_MAX_Q13:read_value={{16{x_max_q13[15]}},x_max_q13};
       `CH4_REG_MIRROR_Y_MIN_Q13:read_value={{16{y_min_q13[15]}},y_min_q13};`CH4_REG_MIRROR_Y_MAX_Q13:read_value={{16{y_max_q13[15]}},y_max_q13};
       `CH4_REG_IMAGE_LINE_COUNT:read_value={16'd0,image_lines};`CH4_REG_MIRROR_X_FREQ_MHZ:read_value=mirror_x_freq_mhz;`CH4_REG_MIRROR_FRAME_FREQ_MHZ:read_value=mirror_frame_freq_mhz;`CH4_REG_MIRROR_FEEDBACK_HZ:read_value={16'd0,mirror_feedback_hz};`CH4_REG_SCAN_POLICY:read_value={31'd0,scan_policy};`CH4_REG_STOP_ACTION:read_value={30'd0,stop_action};`CH4_REG_SAMPLE_RATE_HZ:read_value=32'd25_600_000;
       `CH4_REG_STREAM_RATE_LIMIT_HZ:read_value=stream_rate_hz;`CH4_REG_FUSED_POINT_DROP_COUNT:read_value=dropped_points;
       default:begin status=`CH4_STATUS_INVALID_REGISTER;read_value=0;end endcase
      build_response(frame_type,frame_sequence,status,address,read_value,0,0);end
     `CH4_MSG_WRITE_REG:begin
      if(payload_length!=8)status=`CH4_STATUS_BAD_LENGTH;else case(address[15:0])
       `CH4_REG_MIRROR_X_MIN_Q13:sx_min<=value[15:0];`CH4_REG_MIRROR_X_MAX_Q13:sx_max<=value[15:0];
       `CH4_REG_MIRROR_Y_MIN_Q13:sy_min<=value[15:0];`CH4_REG_MIRROR_Y_MAX_Q13:sy_max<=value[15:0];
       `CH4_REG_MIRROR_X_FREQ_MHZ:if(value>=1000&&value<=20000)s_x_freq_mhz<=value;else status=`CH4_STATUS_OUT_OF_RANGE;
       `CH4_REG_IMAGE_LINE_COUNT:if(value>=2&&value<=2048)s_lines<=value[15:0];else status=`CH4_STATUS_OUT_OF_RANGE;
       `CH4_REG_MIRROR_FEEDBACK_HZ:if(value>=100&&value<=2500)s_feedback_hz<=value[15:0];else status=`CH4_STATUS_OUT_OF_RANGE;
       `CH4_REG_MIRROR_FRAME_FREQ_MHZ:if(value>=1&&value<=40000)s_frame_freq_mhz<=value;else status=`CH4_STATUS_OUT_OF_RANGE;
       `CH4_REG_SCAN_POLICY:if(value<=1)s_scan_policy<=value[0];else status=`CH4_STATUS_OUT_OF_RANGE;
       `CH4_REG_STOP_ACTION:if(value<=2)s_stop_action<=value[1:0];else status=`CH4_STATUS_OUT_OF_RANGE;
       // The WMS feature engine produces at 2 kHz.  Angle-only samples are
       // 29 UART bytes/frame, so 2 kHz consumes about 580 kbps at 921600 baud.
       `CH4_REG_STREAM_RATE_LIMIT_HZ:if(value>=1&&value<=2000)s_stream_rate<=value;else status=`CH4_STATUS_OUT_OF_RANGE;
       default:status=`CH4_STATUS_READ_ONLY;endcase
      config_valid<=((sx_min<sx_max)&&(sy_min<sy_max));build_response(frame_type,frame_sequence,status,address,value,0,0);end
     `CH4_MSG_VALIDATE_CONFIG:begin config_valid<=((sx_min<sx_max)&&(sy_min<sy_max)&&(s_lines>=2)&&(s_stream_rate>=1)&&(s_frame_freq_mhz>0)&&(s_frame_freq_mhz<=(s_x_freq_mhz<<1)));
      build_response(frame_type,frame_sequence,((sx_min<sx_max)&&(sy_min<sy_max)&&(s_lines>=2)&&(s_stream_rate>=1)&&(s_frame_freq_mhz>0)&&(s_frame_freq_mhz<=(s_x_freq_mhz<<1)))?`CH4_STATUS_OK:`CH4_STATUS_INVALID_COMBINATION,0,0,0,0);end
     `CH4_MSG_COMMIT_CONFIG:begin if(!config_valid)status=`CH4_STATUS_INVALID_COMBINATION;else commit_pending<=1;
      build_response(frame_type,frame_sequence,status,0,0,0,0);end
     `CH4_MSG_START_SCAN:begin scan_enable<=1;scan_start_strobe<=1;build_response(frame_type,frame_sequence,status,0,0,0,0);end
     `CH4_MSG_STOP_SCAN:begin scan_enable<=0;if(stop_action==1)begin static_x_q13<=0;static_y_q13<=0;end else if(stop_action==2)begin static_x_q13<=x_min_q13;static_y_q13<=y_min_q13;end build_response(frame_type,frame_sequence,status,0,0,0,0);end
     `CH4_MSG_STATIC_POINT:begin if(payload_length!=4)status=`CH4_STATUS_BAD_LENGTH;else begin scan_enable<=0;static_x_q13<={payload[1],payload[0]};static_y_q13<={payload[3],payload[2]};end build_response(frame_type,frame_sequence,status,0,0,0,0);end
     `CH4_MSG_RETURN_ZERO:begin scan_enable<=0;static_x_q13<=0;static_y_q13<=0;build_response(frame_type,frame_sequence,status,0,0,0,0);end
     `CH4_MSG_RETURN_SCAN_START:begin scan_enable<=0;static_x_q13<=x_min_q13;static_y_q13<=y_min_q13;build_response(frame_type,frame_sequence,status,0,0,0,0);end
     `CH4_MSG_START_ACQUISITION:begin acquisition_enable<=1;build_response(frame_type,frame_sequence,status,0,0,0,0);end
     `CH4_MSG_STOP_ACQUISITION:begin acquisition_enable<=0;build_response(frame_type,frame_sequence,status,0,0,0,0);end
     `CH4_MSG_STREAM_CONFIG:begin
      if(payload_length!=1)status=`CH4_STATUS_BAD_LENGTH;
      else if(payload[0]&8'hFC)status=`CH4_STATUS_OUT_OF_RANGE;
      else begin stream_angle_enable<=payload[0][0];stream_harmonic_enable<=payload[0][1];end
      build_response(frame_type,frame_sequence,status,0,0,0,0);
     end
     `CH4_MSG_STREAM_START:begin stream_enable<=1;build_response(frame_type,frame_sequence,status,0,0,0,0);end
     `CH4_MSG_STREAM_STOP:begin stream_enable<=0;build_response(frame_type,frame_sequence,status,0,0,0,0);end
     `CH4_MSG_STATUS_QUERY:build_response(frame_type,frame_sequence,status,{27'd0,dsp_overflow,stream_enable,acquisition_enable,scan_enable,1'b1},dropped_points,{16'd0,config_revision},0);
     default:build_response(frame_type,frame_sequence,`CH4_STATUS_UNKNOWN_MESSAGE,0,0,0,0);
    endcase
   end
  end
 end
endmodule
