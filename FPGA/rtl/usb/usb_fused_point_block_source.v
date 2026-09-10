`timescale 1ns / 1ps
`include "protocol_defs.vh"

// Converts one frozen 48-byte fused-point payload into a complete application
// frame and then into one zero-padded 4096-byte HSPI payload block.
module usb_fused_point_block_source (
    input  wire         clk,
    input  wire         rst,
    input  wire         point_valid,
    input  wire [383:0] point_payload,
    output wire         point_ready,
    output wire         word_valid,
    output wire [31:0]  word_data,
    output wire         word_last,
    input  wire         word_ready,
    output wire         busy,
    output wire         block_done,
    output wire         frame_too_long
);
    reg [15:0] sequence;
    wire serializer_valid;
    wire [7:0] serializer_data;
    wire serializer_busy;
    wire serializer_done;
    wire packer_ready;
    wire packer_busy;
    wire launch = point_valid && point_ready;

    assign point_ready = !serializer_busy && !packer_busy;
    assign busy = serializer_busy || packer_busy;

    always @(posedge clk) begin
        if (rst)
            sequence <= 16'd0;
        else if (serializer_done)
            sequence <= sequence + 1'b1;
    end

    app_frame_serializer #(.PAYLOAD_BYTES(48)) serializer (
        .clk(clk), .rst(rst), .start(launch),
        .dst(8'h00), .src(8'h01), .msg_type(`CH4_MSG_FUSED_POINT),
        .flags(`CH4_FLAG_DATA_VALID), .sequence(sequence),
        .payload(point_payload), .byte_ready(packer_ready),
        .byte_valid(serializer_valid), .byte_data(serializer_data),
        .busy(serializer_busy), .done(serializer_done)
    );

    usb_hspi_block_packer packer (
        .clk(clk), .rst(rst), .start(launch),
        .in_valid(serializer_valid), .in_data(serializer_data),
        .in_last(serializer_done), .in_ready(packer_ready),
        .out_valid(word_valid), .out_data(word_data), .out_last(word_last),
        .out_ready(word_ready), .busy(packer_busy), .block_done(block_done),
        .frame_too_long(frame_too_long)
    );
endmodule
