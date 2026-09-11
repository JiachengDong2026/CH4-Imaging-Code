`timescale 1ns / 1ps

module usb_harmonic_stream_bridge #(
    parameter integer FRAME_FIFO_ADDR_BITS = 8
) (
    input wire curve_clk, input wire curve_rst, input wire stream_enabled, input wire curve_valid,
    input wire [223:0] curve_payload, output wire curve_ready,
    input wire usb_clk, input wire usb_rst, input wire transmit_request,
    output wire word_valid, output wire [31:0] word_data, output wire word_last,
    input wire word_ready, output wire busy, output wire block_done,
    output wire frame_too_long, output reg [31:0] accepted_frames,
    output reg [31:0] launched_frames, output reg [31:0] dropped_frames
);
    wire fifo_full, fifo_empty, queued_valid, queued_ready;
    wire [223:0] queued_payload;
    wire request_rise;
    reg request_d, request_pending;
    wire source_ready, source_busy, source_done;
    reg enable_u1, enable_u2;
    wire launch = request_pending && source_ready && enable_u2;
    wire push = curve_valid && curve_ready;
    wire pop = queued_valid && queued_ready;

    assign curve_ready = stream_enabled && !fifo_full;
    assign queued_valid = !fifo_empty;
    assign request_rise = transmit_request && !request_d;

    always @(posedge usb_clk) begin
        if (usb_rst) begin request_d <= 1'b0; request_pending <= 1'b0; enable_u1 <= 1'b0; enable_u2 <= 1'b0; end
        else begin
            enable_u1 <= stream_enabled;
            enable_u2 <= enable_u1;
            request_d <= transmit_request;
            if (request_rise) request_pending <= 1'b1;
            else if (launch) request_pending <= 1'b0;
        end
    end

    hspi_async_fifo #(.WIDTH(224), .ADDR_BITS(FRAME_FIFO_ADDR_BITS)) fifo (
        .wr_clk(curve_clk), .wr_rst(curve_rst), .wr_en(push),
        .wr_data(curve_payload), .full(fifo_full), .rd_clk(usb_clk),
        .rd_rst(usb_rst), .rd_en(pop), .rd_data(queued_payload), .empty(fifo_empty));

    always @(posedge curve_clk) begin
        if (curve_rst) begin accepted_frames <= 0; dropped_frames <= 0; end
        else begin
            if (push) accepted_frames <= accepted_frames + 1'b1;
            if (curve_valid && !curve_ready) dropped_frames <= dropped_frames + 1'b1;
        end
    end
    always @(posedge usb_clk)
        if (usb_rst) launched_frames <= 0;
        else if (pop) launched_frames <= launched_frames + 1'b1;

    usb_harmonic_multi_block_source source (
        .clk(usb_clk), .rst(usb_rst), .block_start(launch),
        .block_ready(source_ready), .curve_valid(queued_valid),
        .curve_payload(queued_payload), .curve_ready(queued_ready),
        .word_valid(word_valid), .word_data(word_data), .word_last(word_last),
        .word_ready(word_ready), .busy(source_busy), .block_done(block_done),
        .frame_too_long(frame_too_long));
    assign busy = source_busy;
endmodule
