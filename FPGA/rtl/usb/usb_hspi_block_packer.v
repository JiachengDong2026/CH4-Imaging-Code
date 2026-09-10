`timescale 1ns / 1ps

// Packs one byte-oriented application frame into one 4096-byte HSPI payload.
// Bytes are placed little-endian in each 32-bit word; the unused tail is zero.
module usb_hspi_block_packer (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire        in_valid,
    input  wire [7:0]  in_data,
    input  wire        in_last,
    output wire        in_ready,
    output reg         out_valid,
    output reg  [31:0] out_data,
    output reg         out_last,
    input  wire        out_ready,
    output reg         busy,
    output reg         block_done,
    output reg         frame_too_long
);
    reg [31:0] word_buffer;
    reg [1:0]  byte_lane;
    reg [9:0]  word_index;
    reg        padding;

    wire output_slot_available = !out_valid || out_ready;
    assign in_ready = busy && !padding && !out_last && output_slot_available;

    always @(posedge clk) begin
        if (rst) begin
            word_buffer   <= 32'd0;
            byte_lane     <= 2'd0;
            word_index    <= 10'd0;
            padding       <= 1'b0;
            out_valid     <= 1'b0;
            out_data      <= 32'd0;
            out_last      <= 1'b0;
            busy          <= 1'b0;
            block_done    <= 1'b0;
            frame_too_long <= 1'b0;
        end else begin
            block_done <= 1'b0;

            if (out_valid && out_ready) begin
                out_valid <= 1'b0;
                if (out_last) begin
                    out_last   <= 1'b0;
                    busy       <= 1'b0;
                    block_done <= 1'b1;
                end
            end

            if (start && !busy) begin
                word_buffer    <= 32'd0;
                byte_lane      <= 2'd0;
                word_index     <= 10'd0;
                padding        <= 1'b0;
                out_valid      <= 1'b0;
                out_last       <= 1'b0;
                busy           <= 1'b1;
                frame_too_long <= 1'b0;
            end else if (busy && !out_last && output_slot_available) begin
                if (padding) begin
                    out_valid <= 1'b1;
                    out_data  <= 32'd0;
                    out_last  <= (word_index == 10'd1023);
                    if (word_index != 10'd1023)
                        word_index <= word_index + 1'b1;
                end else if (in_valid) begin
                    case (byte_lane)
                        2'd0: word_buffer[7:0]   <= in_data;
                        2'd1: word_buffer[15:8]  <= in_data;
                        2'd2: word_buffer[23:16] <= in_data;
                        2'd3: word_buffer[31:24] <= in_data;
                    endcase

                    if (in_last || byte_lane == 2'd3) begin
                        out_valid <= 1'b1;
                        case (byte_lane)
                            2'd0: out_data <= {24'd0, in_data};
                            2'd1: out_data <= {16'd0, in_data, word_buffer[7:0]};
                            2'd2: out_data <= {8'd0, in_data, word_buffer[15:0]};
                            default: out_data <= {in_data, word_buffer[23:0]};
                        endcase
                        out_last <= (word_index == 10'd1023);
                        byte_lane <= 2'd0;
                        word_buffer <= 32'd0;

                        if (word_index == 10'd1023) begin
                            if (!in_last)
                                frame_too_long <= 1'b1;
                        end else begin
                            word_index <= word_index + 1'b1;
                            if (in_last)
                                padding <= 1'b1;
                        end
                    end else begin
                        byte_lane <= byte_lane + 1'b1;
                    end
                end
            end
        end
    end
endmodule
