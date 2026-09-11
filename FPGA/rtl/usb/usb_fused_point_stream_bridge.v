`timescale 1ns / 1ps

// Queues real fused-point results and aggregates 67 complete application
// frames into each 4096-byte HSPI payload block.
module usb_fused_point_stream_bridge #(
    parameter integer FRAME_FIFO_ADDR_BITS = 4
) (
    input  wire         fused_clk,
    input  wire         fused_rst,
    input  wire         fused_valid,
    input  wire [383:0] fused_payload,
    output wire         fused_ready,
    input  wire         usb_clk,
    input  wire         usb_rst,
    input  wire         transmit_request,
    output wire         word_valid,
    output wire [31:0]  word_data,
    output wire         word_last,
    input  wire         word_ready,
    output wire         busy,
    output wire         block_done,
    output wire         frame_too_long,
    output reg  [31:0]  accepted_frames,
    output reg  [31:0]  launched_frames,
    output reg  [31:0]  dropped_frames
);
    wire queued_valid;
    wire [383:0] queued_payload;
    wire block_source_ready;
    wire point_ready;
    wire fifo_full;
    wire fifo_empty;
    wire push = fused_valid && fused_ready;
    reg request_d;
    reg request_pending;
    wire request_rise = transmit_request && !request_d;
    wire launch = request_pending && block_source_ready;
    wire pop = queued_valid && point_ready;

    assign fused_ready = !fifo_full;
    assign queued_valid = !fifo_empty;

    // CH569 holds transmit_request high until one HSPI DMA block completes.
    // Convert that level into exactly one queued block launch, while retaining
    // an early request until a fused point becomes available.
    always @(posedge usb_clk) begin
        if (usb_rst) begin
            request_d <= 1'b0;
            request_pending <= 1'b0;
        end else begin
            request_d <= transmit_request;
            if (request_rise)
                request_pending <= 1'b1;
            else if (launch)
                request_pending <= 1'b0;
        end
    end

    hspi_async_fifo #(.WIDTH(384), .ADDR_BITS(FRAME_FIFO_ADDR_BITS)) frame_fifo (
        .wr_clk(fused_clk), .wr_rst(fused_rst),
        .wr_en(push), .wr_data(fused_payload), .full(fifo_full),
        .rd_clk(usb_clk), .rd_rst(usb_rst),
        .rd_en(pop), .rd_data(queued_payload), .empty(fifo_empty)
    );

    always @(posedge fused_clk) begin
        if (fused_rst) begin
            accepted_frames <= 32'd0;
            dropped_frames <= 32'd0;
        end else begin
            if (push)
                accepted_frames <= accepted_frames + 1'b1;
            if (fused_valid && !fused_ready)
                dropped_frames <= dropped_frames + 1'b1;
        end
    end

    always @(posedge usb_clk) begin
        if (usb_rst)
            launched_frames <= 32'd0;
        else if (pop)
            launched_frames <= launched_frames + 1'b1;
    end

    usb_fused_point_multi_block_source block_source (
        .clk(usb_clk), .rst(usb_rst),
        .block_start(launch), .block_ready(block_source_ready),
        .point_valid(queued_valid), .point_payload(queued_payload),
        .point_ready(point_ready),
        .word_valid(word_valid), .word_data(word_data),
        .word_last(word_last), .word_ready(word_ready),
        .busy(busy), .block_done(block_done),
        .frame_too_long(frame_too_long)
    );
endmodule
