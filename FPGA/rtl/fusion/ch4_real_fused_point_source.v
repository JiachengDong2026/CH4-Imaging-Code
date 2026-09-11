`timescale 1ns / 1ps

// Hardware-like stage-2 source using the committed CH4 sample ROM and the
// production calibration, demodulation, smoothing, framing and feature chain.
module ch4_real_fused_point_source #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer GAS_VARIATION = 0,
    parameter integer ADC_NOISE_AMPLITUDE = 24,
    parameter integer CURVE_RATE_HZ = 2000
) (
    input  wire         clk,
    input  wire         rst,
    input  wire [31:0]  curve_rate_hz,
    output wire         fused_valid,
    output wire [383:0] fused_payload,
    output wire curve_valid,
    output wire [223:0] curve_payload
);
    wire [63:0] ticks;
    system_timebase timebase(.clk(clk), .rst(rst), .ticks(ticks));

    wire sample_tick;
    fractional_sample_tick #(.CLOCK_HZ(CLOCK_HZ), .SAMPLE_HZ(25_600_000)) tickgen(
        .clk(clk), .rst(rst), .tick(sample_tick));
    wire rom_valid, rom_start, rom_end;
    wire signed [15:0] rom_sample;
    wire [13:0] rom_index;
    ch4_rom_source #(.DEPTH(12800)) rom(
        .clk(clk), .rst(rst), .enable(1'b1), .advance(sample_tick),
        .valid(rom_valid), .scan_start(rom_start), .scan_end(rom_end),
        .sample(rom_sample), .index(rom_index));

    // Optional bring-up modulation: keep the complete ADC -> quadrature
    // lock-in -> I/Q -> WMS feature path intact while changing the simulated
    // gas concentration once per WMS sweep.  The production image leaves this
    // parameter at zero, which is bit-for-bit equivalent to the fixed ROM.
    reg [5:0] gas_sweep_phase;
    always @(posedge clk) begin
        if (rst)
            gas_sweep_phase <= 6'd0;
        else if (rom_end)
            gas_sweep_phase <= gas_sweep_phase + 1'b1;
    end
    wire signed [7:0] gas_phase_centered = $signed({2'b00, gas_sweep_phase}) - 8'sd32;
    wire signed [31:0] gas_gain_q16 = GAS_VARIATION != 0
        ? 32'sd49152 + (gas_phase_centered * 32'sd512)
        : 32'sd65536;
    wire signed [31:0] gas_sample_wide = ($signed(rom_sample) * gas_gain_q16) >>> 16;

    // Reproducible pseudo-random ADC noise.  A deterministic LFSR keeps
    // simulation and hardware captures repeatable while preventing adjacent
    // WMS sweeps from being bit-identical. ADC_NOISE_AMPLITUDE is peak counts.
    reg [15:0] noise_lfsr;
    wire noise_feedback = noise_lfsr[15] ^ noise_lfsr[13] ^ noise_lfsr[12] ^ noise_lfsr[10];
    always @(posedge clk)
        if (rst) noise_lfsr <= 16'h1ACE;
        else if (rom_valid) noise_lfsr <= {noise_lfsr[14:0], noise_feedback};
    wire signed [8:0] noise_centered = $signed({1'b0, noise_lfsr[7:0]}) - 9'sd128;
    wire signed [31:0] adc_noise = (noise_centered * ADC_NOISE_AMPLITUDE) >>> 7;
    wire signed [31:0] noisy_sample_wide = gas_sample_wide + adc_noise;
    wire signed [15:0] gas_sample = noisy_sample_wide > 32'sd32767 ? 16'sd32767 :
                                    noisy_sample_wide < -32'sd32768 ? -16'sd32768 :
                                    noisy_sample_wide[15:0];

    wire calibrated_valid, saturated;
    wire signed [15:0] calibrated_sample;
    adc_calibration calibration(
        .clk(clk), .rst(rst), .in_valid(rom_valid), .in_sample(gas_sample),
        .offset(32'sd0), .gain_q16(32'sd65536),
        .out_valid(calibrated_valid), .out_sample(calibrated_sample),
        .saturated(saturated));
    reg signed [15:0] aligned_sample;
    always @(posedge clk)
        if (rst) aligned_sample <= 16'sd0;
        else if (calibrated_valid) aligned_sample <= calibrated_sample;

    wire nco_valid;
    wire signed [17:0] sin1, cos1, sin2, cos2;
    nco reference_nco(
        .clk(clk), .rst(rst), .enable(calibrated_valid), .phase_reset(1'b0),
        .phase_inc(32'h02000000), .phase_offset_1f(32'd0),
        .phase_offset_2f(32'h80000000), .valid(nco_valid),
        .sin_1f(sin1), .cos_1f(cos1), .sin_2f(sin2), .cos_2f(cos2));

    wire demod_valid, demod_overflow;
    wire signed [31:0] di1, dq1, di2, dq2;
    wire [32:0] unused_a1, unused_a2;
    demod_chain demod(
        .clk(clk), .rst(rst), .clear(1'b0), .in_valid(nco_valid),
        .sample(aligned_sample), .sin1(sin1), .cos1(cos1),
        .sin2(sin2), .cos2(cos2), .cic_decim(13'd8),
        .tap_count(5'd16), .fir_decim(5'd1), .active_bank(1'b0),
        .coeff_we(1'b0), .coeff_bank(1'b0), .coeff_addr(5'd0),
        .coeff_wdata(18'sd0), .out_valid(demod_valid),
        .i1(di1), .q1(dq1), .i2(di2), .q2(dq2),
        .a1(unused_a1), .a2(unused_a2), .overflow(demod_overflow));

    wire smooth_valid;
    wire signed [31:0] si1, sq1, si2, sq2;
    iq_boxcar16 smoother(
        .clk(clk), .rst(rst), .clear(1'b0), .in_valid(demod_valid),
        .i1(di1), .q1(dq1), .i2(di2), .q2(dq2),
        .out_valid(smooth_valid), .oi1(si1), .oq1(sq1),
        .oi2(si2), .oq2(sq2));

    wire point_valid, scan_start, scan_end;
    wire [31:0] point_index;
    wire signed [31:0] fi1, fq1, fi2, fq2;
    scan_framer framer(
        .clk(clk), .rst(rst), .enable(1'b1), .in_valid(smooth_valid),
        .scan_points(32'd1600), .master_tick(ticks),
        .i1(si1), .q1(sq1), .i2(si2), .q2(sq2),
        .point_valid(point_valid), .scan_start(scan_start), .scan_end(scan_end),
        .point_index(point_index), .out_i1(fi1), .out_q1(fq1),
        .out_i2(fi2), .out_q2(fq2));

    // One uniformly spaced point (every 16th WMS sample) on selected sweeps,
    // matching the proven v2.1 host reconstruction protocol. CURVE_RATE_HZ
    // selects 1..2000 transmitted samples/s at the 2 kHz WMS sweep cadence.
    reg curve_sweep;
    reg [6:0] curve_bin, curve_sample_bin;
    reg signed [31:0] curve_sample_i1, curve_sample_q1;
    reg signed [31:0] curve_sample_i2, curve_sample_q2;
    reg curve_sample_valid;
    reg [11:0] curve_rate_phase;
    wire [31:0] selected_curve_rate = curve_rate_hz == 0 ? CURVE_RATE_HZ : curve_rate_hz;
    wire [12:0] limited_curve_rate = selected_curve_rate > 2000 ? 13'd2000 : selected_curve_rate[12:0];
    wire [12:0] curve_rate_sum = {1'b0, curve_rate_phase} + limited_curve_rate;
    wire curve_sample = point_valid && curve_sweep &&
                        (point_index == ({25'd0, curve_bin} << 4));
    always @(posedge clk) begin
        if (rst) begin
            curve_sweep <= 1'b0;
            curve_bin <= 7'd0;
            curve_sample_bin <= 7'd0;
            curve_sample_i1 <= 32'sd0;
            curve_sample_q1 <= 32'sd0;
            curve_sample_i2 <= 32'sd0;
            curve_sample_q2 <= 32'sd0;
            curve_sample_valid <= 1'b0;
            curve_rate_phase <= 12'd0;
        end else begin
            curve_sample_valid <= curve_sample;
            if (curve_sample) begin
                curve_sample_bin <= curve_bin;
                curve_sample_i1 <= fi1;
                curve_sample_q1 <= fq1;
                curve_sample_i2 <= fi2;
                curve_sample_q2 <= fq2;
            end
            if (point_valid && scan_end) begin
                if (curve_rate_sum >= 13'd2000) begin
                    curve_rate_phase <= curve_rate_sum - 13'd2000;
                    curve_sweep <= 1'b1;
                end else begin
                    curve_rate_phase <= curve_rate_sum[11:0];
                    curve_sweep <= 1'b0;
                end
                if (curve_sweep)
                    curve_bin <= (curve_bin == 7'd99) ? 7'd0 : curve_bin + 1'b1;
            end
        end
    end
    assign curve_valid = curve_sample_valid;
    assign curve_payload = {curve_sample_q2, curve_sample_i2,
                            curve_sample_q1, curve_sample_i1,
                            {25'd0, curve_sample_bin}, ticks};

    wire [63:0] result_time;
    wire signed [31:0] result_i1, result_q1, result_i2, result_q2;
    wire [31:0] result_a1, result_a2;
    wire [15:0] result_flags;
    wms_feature_extractor feature(
        .clk(clk), .rst(rst), .enable(1'b1), .point_valid(point_valid),
        .scan_start(scan_start), .scan_end(scan_end), .point_index(point_index),
        .master_tick(ticks), .i1(fi1), .q1(fq1), .i2(fi2), .q2(fq2),
        .roi_start(32'd160), .roi_end(32'd1440),
        .overflow(demod_overflow), .saturated(saturated),
        .result_valid(fused_valid), .result_time(result_time),
        .result_i1(result_i1), .result_q1(result_q1),
        .result_i2(result_i2), .result_q2(result_q2),
        .result_a1(result_a1), .result_a2(result_a2),
        .quality_flags(result_flags));

    reg [31:0] image_id;
    always @(posedge clk)
        if (rst) image_id <= 32'd0;
        else if (fused_valid) image_id <= image_id + 1'b1;

    fused_point_builder builder(
        .measurement_time(result_time), .image_id(image_id),
        .line_id(16'd0), .point_id(image_id[15:0]),
        .x_angle(16'sd0), .y_angle(16'sd0),
        .i1(result_i1), .q1(result_q1), .i2(result_i2), .q2(result_q2),
        .a1(result_a1), .a2(result_a2), .flags(result_flags),
        .config_revision(16'd1), .payload(fused_payload));
endmodule
