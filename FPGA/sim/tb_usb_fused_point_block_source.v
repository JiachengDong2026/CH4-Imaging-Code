`timescale 1ns / 1ps

module tb_usb_fused_point_block_source;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg point_valid = 1'b0;
    reg [383:0] point_payload = 384'd0;
    wire point_ready;
    wire word_valid;
    wire [31:0] word_data;
    wire word_last;
    reg word_ready = 1'b1;
    wire busy;
    wire block_done;
    wire frame_too_long;
    reg [7:0] bytes [0:4095];
    integer words = 0;
    integer i;
    reg [15:0] crc;

    always #5 clk = ~clk;

    function [15:0] crc_byte;
        input [15:0] crc_in;
        input [7:0] data;
        integer bit_index;
        reg [15:0] value;
        begin
            value = crc_in ^ {data, 8'h00};
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                value = value[15] ? ((value << 1) ^ 16'h1021) : (value << 1);
            crc_byte = value;
        end
    endfunction

    usb_fused_point_block_source dut (
        .clk(clk), .rst(rst), .point_valid(point_valid),
        .point_payload(point_payload), .point_ready(point_ready),
        .word_valid(word_valid), .word_data(word_data), .word_last(word_last),
        .word_ready(word_ready), .busy(busy), .block_done(block_done),
        .frame_too_long(frame_too_long)
    );

    always @(posedge clk) begin
        if (word_valid && word_ready) begin
            bytes[words*4]   = word_data[7:0];
            bytes[words*4+1] = word_data[15:8];
            bytes[words*4+2] = word_data[23:16];
            bytes[words*4+3] = word_data[31:24];
            words <= words + 1;
        end
        if (block_done) begin
            if (words != 1024 || frame_too_long) begin
                $display("FAIL block words=%0d too_long=%0d", words, frame_too_long);
                $finish;
            end
            if (bytes[0] != 8'ha5 || bytes[1] != 8'h5a || bytes[2] != 8'h01 ||
                bytes[3] != 8'h00 || bytes[4] != 8'h01 || bytes[5] != 8'h62 ||
                bytes[6] != 8'h40 || bytes[7] != 8'h00 || bytes[8] != 8'h00 ||
                bytes[9] != 8'd48 || bytes[10] != 8'h00) begin
                $display("FAIL application header");
                $finish;
            end
            for (i = 0; i < 48; i = i + 1)
                if (bytes[11+i] != i[7:0]) begin
                    $display("FAIL payload byte=%0d got=%02x", i, bytes[11+i]);
                    $finish;
                end
            crc = 16'hffff;
            for (i = 2; i < 59; i = i + 1)
                crc = crc_byte(crc, bytes[i]);
            if (bytes[59] != crc[7:0] || bytes[60] != crc[15:8]) begin
                $display("FAIL crc expected=%04x got=%02x%02x", crc, bytes[60], bytes[59]);
                $finish;
            end
            for (i = 61; i < 4096; i = i + 1)
                if (bytes[i] != 8'h00) begin
                    $display("FAIL padding byte=%0d got=%02x", i, bytes[i]);
                    $finish;
                end
            $display("USB_FUSED_POINT_BLOCK_PASS frame_bytes=61 block_bytes=4096 crc=%04x", crc);
            $finish;
        end
    end

    initial begin
        for (i = 0; i < 4096; i = i + 1)
            bytes[i] = 8'hxx;
        for (i = 0; i < 48; i = i + 1)
            point_payload[i*8 +: 8] = i[7:0];
        repeat (4) @(posedge clk);
        rst <= 1'b0;
        @(posedge clk);
        point_valid <= 1'b1;
        @(posedge clk);
        point_valid <= 1'b0;
        repeat (20000) @(posedge clk);
        $display("FAIL timeout");
        $finish;
    end
endmodule
