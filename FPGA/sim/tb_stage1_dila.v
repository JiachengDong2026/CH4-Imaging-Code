`timescale 1ns/1ps

// End-to-end stage-1 datapath check: the committed HITRAN waveform is replayed
// at 25.6 MSPS, demodulated, framed into 2 kHz scans and reduced to WMS peaks.
module tb_stage1_dila;
 reg clk=0,rst=1;always #10 clk=~clk;
 reg[63:0]ticks=0;always @(posedge clk)if(!rst)ticks<=ticks+1'b1;
 wire sample_tick;fractional_sample_tick #(.CLOCK_HZ(50_000_000),.SAMPLE_HZ(25_600_000)) tickgen(.clk(clk),.rst(rst),.tick(sample_tick));
 wire romv,rom_start,rom_end;wire signed[15:0]sample;wire[13:0]rom_index;
 ch4_rom_source #(.DEPTH(12800))rom(.clk(clk),.rst(rst),.enable(1'b1),.advance(sample_tick),.valid(romv),.scan_start(rom_start),.scan_end(rom_end),.sample(sample),.index(rom_index));
 wire ncov;wire signed[17:0]sin1,cos1,sin2,cos2;
 nco refs(.clk(clk),.rst(rst),.enable(romv),.phase_reset(1'b0),.phase_inc(32'h02000000),.phase_offset_1f(0),.phase_offset_2f(32'h80000000),.valid(ncov),.sin_1f(sin1),.cos_1f(cos1),.sin_2f(sin2),.cos_2f(cos2));
 reg signed[15:0]sample_d;always @(posedge clk)if(romv)sample_d<=sample;
 wire dilav,overflow;wire signed[31:0]i1,q1,i2,q2;wire[32:0]a1_unused,a2_unused;
 demod_chain dila(.clk(clk),.rst(rst),.clear(1'b0),.in_valid(ncov),.sample(sample_d),.sin1(sin1),.cos1(cos1),.sin2(sin2),.cos2(cos2),.cic_decim(13'd8),.tap_count(5'd16),.fir_decim(5'd1),.active_bank(1'b0),.coeff_we(1'b0),.coeff_bank(1'b0),.coeff_addr(5'd0),.coeff_wdata(18'sd0),.out_valid(dilav),.i1(i1),.q1(q1),.i2(i2),.q2(q2),.a1(a1_unused),.a2(a2_unused),.overflow(overflow));
 wire smoothv;wire signed[31:0]si1,sq1,si2,sq2;
 iq_boxcar16 smooth(.clk(clk),.rst(rst),.clear(1'b0),.in_valid(dilav),.i1(i1),.q1(q1),.i2(i2),.q2(q2),.out_valid(smoothv),.oi1(si1),.oq1(sq1),.oi2(si2),.oq2(sq2));
 wire pointv,scan_start,scan_end;wire[31:0]point_index;wire signed[31:0]fi1,fq1,fi2,fq2;
 scan_framer framer(.clk(clk),.rst(rst),.enable(1'b1),.in_valid(smoothv),.scan_points(1600),.master_tick(ticks),.i1(si1),.q1(sq1),.i2(si2),.q2(sq2),.point_valid(pointv),.scan_start(scan_start),.scan_end(scan_end),.point_index(point_index),.out_i1(fi1),.out_q1(fq1),.out_i2(fi2),.out_q2(fq2));
 wire featurev;wire[63:0]feature_time;wire signed[31:0]peak_i1,peak_q1,peak_i2,peak_q2;wire[31:0]peak_a1,peak_a2;wire[15:0]flags;
 wms_feature_extractor feature(.clk(clk),.rst(rst),.enable(1'b1),.point_valid(pointv),.scan_start(scan_start),.scan_end(scan_end),.point_index(point_index),.master_tick(ticks),.i1(fi1),.q1(fq1),.i2(fi2),.q2(fq2),.roi_start(160),.roi_end(1440),.overflow(overflow),.saturated(1'b0),.result_valid(featurev),.result_time(feature_time),.result_i1(peak_i1),.result_q1(peak_q1),.result_i2(peak_i2),.result_q2(peak_q2),.result_a1(peak_a1),.result_a2(peak_a2),.quality_flags(flags));
 integer features=0;reg signed[31:0]last_i2=0;
 always @(posedge clk)if(featurev)begin features=features+1;last_i2=peak_i2;if((peak_i1==0&&peak_q1==0)||(peak_i2==0&&peak_q2==0))$fatal(1,"zero harmonic I/Q");if((flags&16'h00D8)!=16'h00D8)$fatal(1,"invalid quality flags %h",flags);end
 initial begin repeat(8)@(posedge clk);rst=0;repeat(90000)@(posedge clk);if(features<3)$fatal(1,"expected at least 3 features, got %0d",features);$display("FPGA_STAGE1_DILA_PASS features=%0d last_i2=%0d",features,last_i2);$finish;end
endmodule
