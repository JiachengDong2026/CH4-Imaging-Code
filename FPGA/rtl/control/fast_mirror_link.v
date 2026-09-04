`timescale 1ns/1ps
// Fast-mirror native UART adapter and continuous raster trajectory generator.
// The trajectory policy is aligned with the verified uart_bridge_v4 lower-level
// controller: frequency priority uses 56 command slots per X period, waveform
// priority uses 112 slots and feedback-qualified endpoint windows.
module fast_mirror_uart_tx #(parameter integer CLOCK_HZ=50_000_000, BAUD=4_608_000)(
 input wire clk,rst,start,input wire [7:0] data,output reg tx,busy,done
);
 reg [32:0] phase; reg [3:0] bit_index; reg [9:0] shift;
 wire [33:0] phase_sum={1'b0,phase}+BAUD; wire bit_tick=(phase_sum>=CLOCK_HZ);
 always @(posedge clk) begin
  if(rst) begin tx<=1;busy<=0;done<=0;phase<=0;bit_index<=0;shift<=10'h3ff;end
  else begin
   done<=0;
   if(!busy&&start) begin tx<=0;busy<=1;phase<=0;bit_index<=0;shift<={1'b1,data,1'b0};end
   else if(busy) begin
    if(bit_tick) begin
     phase<=phase_sum-CLOCK_HZ;shift<={1'b1,shift[9:1]};
     if(bit_index==9) begin tx<=1;busy<=0;done<=1;end
     else begin bit_index<=bit_index+1'b1;tx<=shift[1];end
    end else phase<=phase_sum[32:0];
   end
  end
 end
endmodule

module fast_mirror_uart_rx #(parameter integer CLOCK_HZ=50_000_000, BAUD=4_608_000)(
 input wire clk,rst,rx,output reg valid,output reg [7:0] data
);
 localparam integer HALF_TICKS=(CLOCK_HZ/(BAUD*2));
 localparam [1:0] IDLE=0,START=1,DATA=2,STOP=3;
 (* ASYNC_REG="TRUE" *) reg rx_meta,rx_sync;
 reg [1:0] state;reg [3:0] start_count;reg [2:0] bit_index;reg [7:0] shift;reg [32:0] phase;
 wire [33:0] phase_sum={1'b0,phase}+BAUD;wire bit_tick=(phase_sum>=CLOCK_HZ);
 always @(posedge clk) begin if(rst) begin rx_meta<=1;rx_sync<=1;end else begin rx_meta<=rx;rx_sync<=rx_meta;end end
 always @(posedge clk) begin
  if(rst) begin valid<=0;data<=0;state<=IDLE;start_count<=0;bit_index<=0;shift<=0;phase<=0;end
  else begin
   valid<=0;
   case(state)
    IDLE:if(!rx_sync)begin state<=START;start_count<=0;end
    START:if(start_count>=HALF_TICKS-1)begin if(!rx_sync)begin state<=DATA;bit_index<=0;phase<=0;end else state<=IDLE;end else start_count<=start_count+1'b1;
    DATA:if(bit_tick)begin phase<=phase_sum-CLOCK_HZ;shift[bit_index]<=rx_sync;if(bit_index==7)state<=STOP;else bit_index<=bit_index+1'b1;end else phase<=phase_sum[32:0];
    STOP:if(bit_tick)begin phase<=phase_sum-CLOCK_HZ;if(rx_sync)begin data<=shift;valid<=1;end state<=IDLE;end else phase<=phase_sum[32:0];
    default:state<=IDLE;
   endcase
  end
 end
endmodule

module fast_mirror_link #(parameter integer CLOCK_HZ=50_000_000,MIRROR_BAUD=4_608_000)(
 input wire clk,rst,scan_enable,scan_start,input wire signed [15:0] x_min,x_max,y_min,y_max,static_x,static_y,
 input wire [31:0] x_frequency_mhz,frame_frequency_mhz,input wire scan_policy,input wire [15:0] feedback_hz,input wire mirror_rx,output wire mirror_tx,
 output reg feedback_valid,output reg signed [15:0] feedback_x,feedback_y,output reg [31:0] feedback_errors,
 output wire scan_finished
);
 // Native feedback validity is determined by framing and XOR.  FREQ is the
 // device-reported code and may be quantized, so it must not reject an angle.
 wire rx_valid;wire [7:0] rx_data;
 fast_mirror_uart_rx #(.CLOCK_HZ(CLOCK_HZ),.BAUD(MIRROR_BAUD)) receiver(.clk(clk),.rst(rst),.rx(mirror_rx),.valid(rx_valid),.data(rx_data));
 reg [3:0] rx_count;reg [7:0] rx_frame[0:8];reg [7:0] rx_check;
 always @(posedge clk) begin
  if(rst)begin rx_count<=0;feedback_valid<=0;feedback_x<=0;feedback_y<=0;feedback_errors<=0;end
  else begin
   feedback_valid<=0;
   if(rx_valid)case(rx_count)
    0:if(rx_data==8'h55)begin rx_frame[0]<=rx_data;rx_count<=1;end
    1:if(rx_data==8'haa)begin rx_frame[1]<=rx_data;rx_count<=2;end else if(rx_data==8'h55)begin rx_frame[0]<=rx_data;rx_count<=1;end else rx_count<=0;
    default:begin
     rx_frame[rx_count]<=rx_data;
     if(rx_count==8)begin
      rx_check=rx_frame[2]^rx_frame[3]^rx_frame[4]^rx_frame[5]^rx_frame[6]^8'hff;
      if(rx_data==8'hcc&&rx_check==rx_frame[7])begin feedback_x<={rx_frame[3],rx_frame[4]};feedback_y<={rx_frame[5],rx_frame[6]};feedback_valid<=1;end
      else feedback_errors<=feedback_errors+1'b1;
      rx_count<=0;
     end else rx_count<=rx_count+1'b1;
    end
   endcase
  end
 end

 // Command rate: 56*x_freq (frequency priority) or 112*x_freq (waveform
 // priority).  The phase accumulator keeps the rate exact without a divider.
 localparam [63:0] COMMAND_THRESHOLD=64'd1000*CLOCK_HZ;
 wire [6:0] command_slots_per_period=scan_policy?7'd112:7'd56;
 wire [63:0] command_increment={32'd0,x_frequency_mhz}*command_slots_per_period;
 reg [63:0] command_phase;wire [63:0] command_phase_sum=command_phase+command_increment;
 reg scan_ready;wire command_tick=scan_enable&&scan_ready&&(command_phase_sum>=COMMAND_THRESHOLD);
 wire high_rate_profile=(x_frequency_mhz>=32'd15000);
 wire [5:0] horizontal_steps=scan_policy?6'd24:(high_rate_profile?6'd20:6'd24);
 reg [5:0] x_point_index;reg signed [31:0] x_step_q16,x_pos_q16;
 reg signed [15:0] target_x,target_y;reg x_reverse,endpoint_active,endpoint_phase;
 reg [4:0] settle_tick_count;reg [2:0] stable_sample_count;reg signed [15:0] previous_feedback_x,previous_feedback_y;
 reg [31:0] line_index,mirror_rows;reg signed [31:0] y_step_q16,y_acc_q16;

 function [2:0] horizontal_weight;
  input [5:0] point_index;input high_rate_mode;input waveform_mode;
  begin
   if(waveform_mode)case(point_index)
    0,1,2,21,22,23:horizontal_weight=1;3,4,19,20:horizontal_weight=2;5,6,7,16,17,18:horizontal_weight=3;default:horizontal_weight=4;
   endcase else if(high_rate_mode)case(point_index)
    0,1,2,17,18,19:horizontal_weight=1;3,16:horizontal_weight=2;4,15:horizontal_weight=3;5,14:horizontal_weight=4;default:horizontal_weight=5;
   endcase else case(point_index)
    0,1,2,21,22,23:horizontal_weight=1;3,4,19,20:horizontal_weight=2;5,6,7,16,17,18:horizontal_weight=3;default:horizontal_weight=4;
   endcase
  end
 endfunction
 function [16:0] signed_abs_diff;
  input signed [15:0] a;input signed [15:0] b;reg signed [16:0] difference;
  begin difference={a[15],a}-{b[15],b};signed_abs_diff=difference[16]?-difference:difference;end
 endfunction
 wire [2:0] current_x_weight=horizontal_weight(x_point_index,high_rate_profile,scan_policy);
 wire signed [31:0] weighted_x_step=(current_x_weight==1)?x_step_q16:(current_x_weight==2)?(x_step_q16<<<1):(current_x_weight==3)?(x_step_q16+(x_step_q16<<<1)):(current_x_weight==4)?(x_step_q16<<<2):(x_step_q16+(x_step_q16<<<2));
 wire signed [15:0] row_endpoint_x=x_reverse?x_min:x_max;
 wire signed [31:0] next_y_q16=y_acc_q16+y_step_q16;
 wire signed [31:0] next_y_raw=$signed({{16{y_min[15]}},y_min})+(next_y_q16>>>16);
 wire x_position_stable=(signed_abs_diff(feedback_x,target_x)<=17'd82);
 wire y_position_stable=(signed_abs_diff(feedback_y,target_y)<=17'd82);
 wire x_velocity_stable=(signed_abs_diff(feedback_x,previous_feedback_x)<=17'd16);
 wire y_velocity_stable=(signed_abs_diff(feedback_y,previous_feedback_y)<=17'd16);
 wire [3:0] post_y_settle_max_ticks=high_rate_profile?4'd6:4'd2;
 wire endpoint_timed_out=(!endpoint_phase&&settle_tick_count>=5'd2)||(endpoint_phase&&settle_tick_count>=post_y_settle_max_ticks);
 wire endpoint_feedback_stable=(!endpoint_phase&&stable_sample_count>=3'd3)||(endpoint_phase&&stable_sample_count>=3'd1);
 // Waveform mode reserves a fixed 31 command-slot endpoint window.  Feedback
 // can trigger the Y step sooner, but can never alter the requested X period.
 wire waveform_pre_y_timeout=(settle_tick_count>=5'd14);
 wire waveform_endpoint_complete=(settle_tick_count>=5'd31);
 wire endpoint_phase_complete=scan_policy?((!endpoint_phase&&(endpoint_feedback_stable||waveform_pre_y_timeout))||(endpoint_phase&&waveform_endpoint_complete)):endpoint_timed_out;

 // Sequential configuration arithmetic: X range/64, rows=(2*X)/frame, Y/r.
 localparam [1:0] CALC_IDLE=0,CALC_X_STEP=1,CALC_ROWS=2,CALC_Y_STEP=3;
 reg [1:0] calc_state;reg [63:0] div_quotient;reg [32:0] div_remainder;reg [31:0] div_divisor;reg [6:0] div_count;reg [32:0] rem_shift;reg [63:0] quot_shift;
 reg scan_enable_d,scan_complete,command_pending,command_is_scan,idle_retarget_pending;reg signed [15:0] command_x,command_y;reg [18:0] static_count;
 wire static_tick=!scan_enable&&(static_count==19'd499999);
 assign scan_finished=scan_complete;
 always @(posedge clk) begin
  if(rst)begin
   command_phase<=0;x_point_index<=0;x_step_q16<=0;x_pos_q16<=0;target_x<=0;target_y<=0;x_reverse<=0;endpoint_active<=0;endpoint_phase<=0;settle_tick_count<=0;stable_sample_count<=0;previous_feedback_x<=0;previous_feedback_y<=0;line_index<=0;mirror_rows<=1;y_step_q16<=0;y_acc_q16<=0;
   calc_state<=CALC_IDLE;div_quotient<=0;div_remainder<=0;div_divisor<=1;div_count<=0;scan_ready<=0;scan_enable_d<=0;scan_complete<=0;command_pending<=0;command_is_scan<=0;idle_retarget_pending<=0;command_x<=0;command_y<=0;static_count<=0;
  end else begin
   command_pending<=0;scan_enable_d<=scan_enable;
   if(scan_enable&&(scan_start||!scan_enable_d))begin
    command_phase<=0;x_point_index<=0;target_x<=x_min;target_y<=y_min;x_reverse<=0;endpoint_active<=0;endpoint_phase<=0;settle_tick_count<=0;stable_sample_count<=0;previous_feedback_x<=x_min;previous_feedback_y<=y_min;line_index<=0;y_acc_q16<=0;x_pos_q16<=$signed({{16{x_min[15]}},x_min})<<<16;scan_ready<=0;scan_complete<=0;idle_retarget_pending<=0;static_count<=0;
    div_quotient<={16'd0,($signed({{16{x_max[15]}},x_max})-$signed({{16{x_min[15]}},x_min})),16'd0};div_remainder<=0;div_divisor<=64;div_count<=0;calc_state<=CALC_X_STEP;
   end else if(calc_state!=CALC_IDLE)begin
    rem_shift={div_remainder[31:0],div_quotient[63]};quot_shift={div_quotient[62:0],1'b0};
    if(rem_shift>={1'b0,div_divisor})begin rem_shift=rem_shift-{1'b0,div_divisor};quot_shift[0]=1;end
    if(div_count==63)begin
     if(calc_state==CALC_X_STEP)begin x_step_q16<=quot_shift[31:0];div_quotient<={31'd0,x_frequency_mhz,1'b0};div_remainder<=0;div_divisor<=(frame_frequency_mhz==0)?1:frame_frequency_mhz;div_count<=0;calc_state<=CALC_ROWS;end
     else if(calc_state==CALC_ROWS)begin mirror_rows<=(quot_shift[31:0]==0)?1:quot_shift[31:0];div_quotient<={16'd0,($signed({{16{y_max[15]}},y_max})-$signed({{16{y_min[15]}},y_min})),16'd0};div_remainder<=0;div_divisor<=(quot_shift[31:0]==0)?1:quot_shift[31:0];div_count<=0;calc_state<=CALC_Y_STEP;end
     else begin y_step_q16<=quot_shift[31:0];scan_ready<=1;calc_state<=CALC_IDLE;command_x<=x_min;command_y<=y_min;command_pending<=1;command_is_scan<=1;end
    end else begin div_quotient<=quot_shift;div_remainder<=rem_shift;div_count<=div_count+1'b1;end
   end else if(scan_enable&&!scan_complete)begin
    static_count<=0;
    if(command_tick)begin
     command_phase<=command_phase_sum-COMMAND_THRESHOLD;command_x<=target_x;command_y<=target_y;command_pending<=1;command_is_scan<=1;
     if(!endpoint_active)begin
      if(x_point_index==horizontal_steps)begin endpoint_active<=1;endpoint_phase<=0;settle_tick_count<=0;stable_sample_count<=0;previous_feedback_x<=feedback_x;previous_feedback_y<=feedback_y;end
      else begin
       x_point_index<=x_point_index+1'b1;
       if(x_point_index==horizontal_steps-1'b1)begin x_pos_q16<=$signed({{16{row_endpoint_x[15]}},row_endpoint_x})<<<16;target_x<=row_endpoint_x;end
       else if(!x_reverse)begin x_pos_q16<=x_pos_q16+weighted_x_step;target_x<=(x_pos_q16+weighted_x_step)>>>16;end
       else begin x_pos_q16<=x_pos_q16-weighted_x_step;target_x<=(x_pos_q16-weighted_x_step)>>>16;end
      end
     end else begin
      if(!(scan_policy?waveform_endpoint_complete:endpoint_timed_out))settle_tick_count<=settle_tick_count+1'b1;
      if(endpoint_phase_complete)begin
       stable_sample_count<=0;if(!scan_policy)settle_tick_count<=0;
       if(!endpoint_phase)begin
        // Y changes only after X has held the exact endpoint target.
        // The final horizontal row has already reached Y_MAX.  Finish there
        // instead of wrapping Y to the first row and starting another image.
        if(line_index+1>=mirror_rows)begin scan_complete<=1;endpoint_active<=0;endpoint_phase<=0;command_phase<=0;end
        else begin line_index<=line_index+1'b1;y_acc_q16<=next_y_q16;target_y<=((line_index+1)>=mirror_rows-1)?y_max:next_y_raw[15:0];end
        endpoint_phase<=1;
       end else begin endpoint_active<=0;endpoint_phase<=0;x_reverse<=~x_reverse;x_point_index<=0;end
      end
     end
    end else command_phase<=command_phase_sum;
    if(endpoint_active&&feedback_valid)begin
     previous_feedback_x<=feedback_x;previous_feedback_y<=feedback_y;
     if((!endpoint_phase&&x_position_stable&&x_velocity_stable)||(endpoint_phase&&y_position_stable&&y_velocity_stable))begin if(stable_sample_count<7)stable_sample_count<=stable_sample_count+1'b1;end else stable_sample_count<=0;
    end
   end else if(scan_enable)begin
    // A completed scan holds its final endpoint until STOP_SCAN or START_SCAN.
    command_phase<=0;endpoint_active<=0;endpoint_phase<=0;static_count<=0;
   end else begin
    // On STOP_SCAN, wait one clock so the command plane's static target is
    // visible, then transmit it immediately.  This prevents a late scan frame
    // or the 100 Hz idle refresh from producing a post-stop twitch.
    command_phase<=0;scan_ready<=0;calc_state<=CALC_IDLE;endpoint_active<=0;endpoint_phase<=0;x_point_index<=0;x_reverse<=0;line_index<=0;y_acc_q16<=0;target_x<=static_x;target_y<=static_y;
    if(scan_enable_d)begin static_count<=0;idle_retarget_pending<=1;end
    else if(idle_retarget_pending)begin static_count<=0;idle_retarget_pending<=0;command_x<=static_x;command_y<=static_y;command_pending<=1;command_is_scan<=0;end
    else if(static_tick)begin static_count<=0;command_x<=static_x;command_y<=static_y;command_pending<=1;command_is_scan<=0;end else static_count<=static_count+1'b1;
   end
  end
 end

 // A native 9-byte frame takes about 19.6 us at 4.608 Mbps, whereas the
 // maximum command period is about 446 us.  Latch its coordinates so a later
 // trajectory update cannot corrupt a frame already being serialized.
 reg frame_busy;reg [3:0] frame_index;reg tx_start;reg [7:0] tx_data;reg signed [15:0] frame_x,frame_y;
 reg deferred_valid,deferred_is_scan;reg signed [15:0] deferred_x,deferred_y;wire tx_busy,tx_done;wire [7:0] feedback_code=feedback_hz/100;
 fast_mirror_uart_tx #(.CLOCK_HZ(CLOCK_HZ),.BAUD(MIRROR_BAUD)) transmitter(.clk(clk),.rst(rst),.start(tx_start),.data(tx_data),.tx(mirror_tx),.busy(tx_busy),.done(tx_done));
 task load_command;input signed [15:0] next_x;input signed [15:0] next_y;begin frame_busy<=1;frame_index<=0;frame_x<=next_x;frame_y<=next_y;tx_data<=8'h55;end endtask
 always @(posedge clk) begin
  if(rst)begin frame_busy<=0;frame_index<=0;tx_start<=0;tx_data<=0;frame_x<=0;frame_y<=0;deferred_valid<=0;deferred_is_scan<=0;deferred_x<=0;deferred_y<=0;end
  else begin
   tx_start<=0;
   // Discard queued scan targets as soon as STOP_SCAN takes effect.  A byte
   // already on the wire is allowed to finish, preserving the native frame.
   if(!scan_enable&&deferred_valid&&deferred_is_scan)deferred_valid<=0;
   if(command_pending&&!(frame_busy&&tx_done&&frame_index==8)&&!(command_is_scan&&!scan_enable))begin if(!frame_busy)load_command(command_x,command_y);else begin deferred_valid<=1;deferred_is_scan<=command_is_scan;deferred_x<=command_x;deferred_y<=command_y;end end
   if(!scan_enable&&frame_busy&&!tx_busy&&!tx_start)begin frame_busy<=0;frame_index<=0;end
   else if(frame_busy)begin
    if(tx_done)begin
     if(frame_index==8)begin
      frame_busy<=0;frame_index<=0;
       if(deferred_valid&&(scan_enable||!deferred_is_scan))begin
        load_command(deferred_x,deferred_y);
       // Preserve a command that coincides with completion of an older
       // deferred frame; it becomes the next deferred command.
        deferred_valid<=command_pending&&(scan_enable||!command_is_scan);
        if(command_pending)begin deferred_is_scan<=command_is_scan;deferred_x<=command_x;deferred_y<=command_y;end
       end else if(command_pending&&!(command_is_scan&&!scan_enable))load_command(command_x,command_y);
     end
     else begin
      frame_index<=frame_index+1'b1;
      case(frame_index+1'b1)
       1:tx_data<=8'haa;2:tx_data<=feedback_code;3:tx_data<=frame_x[15:8];4:tx_data<=frame_x[7:0];5:tx_data<=frame_y[15:8];6:tx_data<=frame_y[7:0];7:tx_data<=feedback_code^frame_x[15:8]^frame_x[7:0]^frame_y[15:8]^frame_y[7:0]^8'hff;default:tx_data<=8'hcc;
      endcase
     end
    end else if(!tx_busy&&!tx_start)tx_start<=1;
   end
  end
 end
endmodule
