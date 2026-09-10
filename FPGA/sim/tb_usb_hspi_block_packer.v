`timescale 1ns / 1ps

module tb_usb_hspi_block_packer;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg start = 1'b0;
    reg in_valid = 1'b0;
    reg [7:0] in_data = 8'd0;
    reg in_last = 1'b0;
    wire in_ready;
    wire out_valid;
    wire [31:0] out_data;
    wire out_last;
    reg out_ready = 1'b1;
    wire busy;
    wire block_done;
    wire frame_too_long;
    integer sent = 0;
    integer words = 0;
    integer cycles = 0;
    integer lane;
    reg [7:0] observed;

    always #5 clk = ~clk;

    usb_hspi_block_packer dut (
        .clk(clk), .rst(rst), .start(start),
        .in_valid(in_valid), .in_data(in_data), .in_last(in_last),
        .in_ready(in_ready), .out_valid(out_valid), .out_data(out_data),
        .out_last(out_last), .out_ready(out_ready), .busy(busy),
        .block_done(block_done), .frame_too_long(frame_too_long)
    );

    always @(posedge clk) begin
        if (!rst) begin
            cycles <= cycles + 1;
            out_ready <= ((cycles % 7) != 3);
            if (in_valid && in_ready) begin
                sent <= sent + 1;
                if (sent == 60) begin
                    in_valid <= 1'b0;
                    in_last <= 1'b0;
                end else begin
                    in_data <= sent + 1;
                    in_last <= (sent == 59);
                end
            end
            if (out_valid && out_ready) begin
                for (lane = 0; lane < 4; lane = lane + 1) begin
                    observed = out_data[lane*8 +: 8];
                    if ((words*4 + lane) < 61) begin
                        if (observed !== ((words*4 + lane) & 8'hff)) begin
                            $display("FAIL data byte=%0d got=%02x", words*4+lane, observed);
                            $finish;
                        end
                    end else if (observed !== 8'h00) begin
                        $display("FAIL padding byte=%0d got=%02x", words*4+lane, observed);
                        $finish;
                    end
                end
                words <= words + 1;
                if (out_last && words != 1023) begin
                    $display("FAIL early out_last word=%0d", words);
                    $finish;
                end
            end
            if (block_done) begin
                if (words != 1024 || frame_too_long) begin
                    $display("FAIL words=%0d too_long=%0d", words, frame_too_long);
                    $finish;
                end
                $display("USB_HSPI_BLOCK_PACKER_PASS words=%0d frame_bytes=%0d", words, sent);
                $finish;
            end
        end
    end

    initial begin
        repeat (4) @(posedge clk);
        rst <= 1'b0;
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;
        in_valid <= 1'b1;
        in_data <= 8'h00;
        in_last <= 1'b0;
        repeat (20000) @(posedge clk);
        $display("FAIL timeout");
        $finish;
    end
endmodule
