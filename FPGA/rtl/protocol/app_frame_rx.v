`timescale 1ns/1ps
`include "protocol_defs.vh"

// Byte-stream parser for the frozen unified application frame. Payload bytes
// are intentionally not buffered here; stage 1 will route them to command and
// stream consumers through valid/ready FIFOs.
module app_frame_rx #(
    parameter integer MAX_PAYLOAD = `CH4_MAX_PAYLOAD
)(
    input wire clk,
    input wire rst,
    input wire byte_valid,
    input wire [7:0] byte_data,
    output reg frame_valid,
    output reg frame_error,
    output reg crc_error,
    output reg length_error,
    output reg version_error,
    output reg [7:0] frame_version,
    output reg [7:0] frame_dst,
    output reg [7:0] frame_src,
    output reg [7:0] frame_type,
    output reg [7:0] frame_flags,
    output reg [15:0] frame_sequence,
    output reg [15:0] frame_payload_length
);
    localparam [2:0] WAIT_A5=3'd0, WAIT_5A=3'd1, HEADER=3'd2,
                     PAYLOAD=3'd3, CRC_LOW=3'd4, CRC_HIGH=3'd5;
    reg [2:0] state;
    reg [3:0] header_index;
    reg [15:0] payload_count;
    reg [15:0] crc_value;
    reg [7:0] crc_low;
    reg version_bad;

    function [15:0] crc16_byte;
        input [15:0] crc_in;
        input [7:0] data;
        integer bit_index;
        reg [15:0] value;
        begin
            value = crc_in ^ (data << 8);
            for(bit_index=0; bit_index<8; bit_index=bit_index+1)
                value = value[15] ? (value << 1) ^ 16'h1021 : value << 1;
            crc16_byte = value;
        end
    endfunction

    always @(posedge clk) begin
        if(rst) begin
            state<=WAIT_A5; header_index<=0; payload_count<=0; crc_value<=16'hFFFF;
            crc_low<=0; version_bad<=0; frame_valid<=0; frame_error<=0;
            crc_error<=0; length_error<=0; version_error<=0;
            frame_version<=0; frame_dst<=0; frame_src<=0; frame_type<=0;
            frame_flags<=0; frame_sequence<=0; frame_payload_length<=0;
        end else begin
            frame_valid<=0; frame_error<=0; crc_error<=0; length_error<=0; version_error<=0;
            if(byte_valid) begin
                case(state)
                    WAIT_A5: if(byte_data==`CH4_SOF0) state<=WAIT_5A;
                    WAIT_5A: begin
                        if(byte_data==`CH4_SOF1) begin
                            state<=HEADER; header_index<=0; crc_value<=16'hFFFF; version_bad<=0;
                        end else if(byte_data!=`CH4_SOF0) state<=WAIT_A5;
                    end
                    HEADER: begin
                        crc_value<=crc16_byte(crc_value,byte_data);
                        case(header_index)
                            0: begin frame_version<=byte_data; version_bad<=(byte_data!=`CH4_PROTOCOL_VERSION); end
                            1: frame_dst<=byte_data;
                            2: frame_src<=byte_data;
                            3: frame_type<=byte_data;
                            4: frame_flags<=byte_data;
                            5: frame_sequence[7:0]<=byte_data;
                            6: frame_sequence[15:8]<=byte_data;
                            7: frame_payload_length[7:0]<=byte_data;
                            8: begin
                                frame_payload_length[15:8]<=byte_data;
                                payload_count<=0;
                                if({byte_data,frame_payload_length[7:0]}>MAX_PAYLOAD) begin
                                    state<=WAIT_A5; frame_error<=1; length_error<=1;
                                end else if({byte_data,frame_payload_length[7:0]}==0)
                                    state<=CRC_LOW;
                                else state<=PAYLOAD;
                            end
                            default: state<=WAIT_A5;
                        endcase
                        if(header_index!=8) header_index<=header_index+1'b1;
                    end
                    PAYLOAD: begin
                        crc_value<=crc16_byte(crc_value,byte_data);
                        if(payload_count+1'b1>=frame_payload_length) state<=CRC_LOW;
                        payload_count<=payload_count+1'b1;
                    end
                    CRC_LOW: begin crc_low<=byte_data; state<=CRC_HIGH; end
                    CRC_HIGH: begin
                        state<=WAIT_A5;
                        if({byte_data,crc_low}!=crc_value) begin
                            frame_error<=1; crc_error<=1;
                        end else if(version_bad) begin
                            frame_error<=1; version_error<=1;
                        end else frame_valid<=1;
                    end
                    default: state<=WAIT_A5;
                endcase
            end
        end
    end
endmodule
