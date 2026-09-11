`timescale 1ns / 1ps
`include "protocol_defs.vh"

// Packs 99 HARMONIC_CURVE frames (41 bytes each) into one 4096-byte block.
// The remaining 37 bytes are explicitly zero padded.
module usb_harmonic_multi_block_source #(
    parameter integer FRAMES_PER_BLOCK = 99
) (
    input wire clk, input wire rst, input wire block_start,
    output wire block_ready, input wire curve_valid,
    input wire [223:0] curve_payload, output wire curve_ready,
    output wire word_valid, output wire [31:0] word_data,
    output wire word_last, input wire word_ready, output wire busy,
    output wire block_done, output wire frame_too_long
);
    reg [15:0] sequence;
    reg [7:0] frames_started;
    wire serializer_valid, serializer_busy, serializer_done;
    wire [7:0] serializer_data;
    wire packer_ready, packer_busy;
    wire curve_launch = curve_valid && curve_ready;
    wire final_frame_done = serializer_done && (frames_started == FRAMES_PER_BLOCK);

    assign block_ready = !serializer_busy && !packer_busy;
    assign curve_ready = packer_busy && !serializer_busy &&
                         (frames_started < FRAMES_PER_BLOCK);
    assign busy = serializer_busy || packer_busy;

    always @(posedge clk) begin
        if (rst) begin
            sequence <= 16'd0;
            frames_started <= 7'd0;
        end else begin
            if (block_start && block_ready)
                frames_started <= 7'd0;
            else if (curve_launch)
                frames_started <= frames_started + 1'b1;
            if (serializer_done)
                sequence <= sequence + 1'b1;
        end
    end

    app_frame_serializer #(.PAYLOAD_BYTES(28)) serializer (
        .clk(clk), .rst(rst), .start(curve_launch),
        .dst(8'h00), .src(8'h01), .msg_type(`CH4_MSG_HARMONIC_CURVE),
        .flags(`CH4_FLAG_DATA_VALID), .sequence(sequence),
        .payload(curve_payload), .byte_ready(packer_ready),
        .byte_valid(serializer_valid), .byte_data(serializer_data),
        .busy(serializer_busy), .done(serializer_done)
    );

    usb_hspi_block_packer packer (
        .clk(clk), .rst(rst), .start(block_start && block_ready),
        .in_valid(serializer_valid), .in_data(serializer_data),
        .in_last(final_frame_done), .in_ready(packer_ready),
        .out_valid(word_valid), .out_data(word_data), .out_last(word_last),
        .out_ready(word_ready), .busy(packer_busy), .block_done(block_done),
        .frame_too_long(frame_too_long)
    );
endmodule
