`timescale 1ns / 1ps

// Stage-2 bring-up image: emits one protocol-valid FUSED_POINT block for each
// rising Tx_Ctrl request from the CH569 stream firmware.
module ch4_usb3_stream_test_top (
    input  wire        Clk_50M_In,
    input  wire        Resetn,
    output wire        Bitstream_Done,
    input  wire        HRACT,
    input  wire        HRCLK,
    input  wire        HRVLD,
    output wire        HTACK,
    output wire        HTCLK,
    input  wire        HTRDY,
    output wire        HTREQ,
    output wire        HTVLD,
    inout  wire [31:0] HD,
    input  wire        Rx_Ctrl,
    input  wire        Tx_Ctrl,
    output wire        led
);
    wire clk120m;
    wire clk30m;
    wire locked;
    reg [1:0] tx_clk_div;
    reg [63:0] system_ticks;
    reg [15:0] point_id;

    assign Bitstream_Done = locked;
    assign led = locked;
    assign HTACK = 1'b0;

    clk_wiz_0 clk_wiz_0_inst (
        .clk_out1(clk120m), .reset(~Resetn), .locked(locked),
        .clk_in1(Clk_50M_In)
    );

    always @(posedge clk120m or negedge locked) begin
        if (!locked) begin
            tx_clk_div <= 2'b00;
            system_ticks <= 64'd0;
        end else begin
            tx_clk_div <= tx_clk_div + 1'b1;
            system_ticks <= system_ticks + 1'b1;
        end
    end
    BUFG tx_clk_30m_bufg (.I(tx_clk_div[1]), .O(clk30m));

    reg tx_ctrl_r1;
    reg tx_ctrl_r2;
    reg tx_ctrl_r3;
    reg point_request;
    wire point_ready;
    always @(posedge clk120m or negedge locked) begin
        if (!locked) begin
            tx_ctrl_r1 <= 1'b0;
            tx_ctrl_r2 <= 1'b0;
            tx_ctrl_r3 <= 1'b0;
            point_request <= 1'b0;
            point_id <= 16'd0;
        end else begin
            tx_ctrl_r1 <= Tx_Ctrl;
            tx_ctrl_r2 <= tx_ctrl_r1;
            tx_ctrl_r3 <= tx_ctrl_r2;
            if (tx_ctrl_r2 && !tx_ctrl_r3)
                point_request <= 1'b1;
            else if (point_request && point_ready) begin
                point_request <= 1'b0;
                point_id <= point_id + 1'b1;
            end
        end
    end

    wire [383:0] point_payload;
    fused_point_builder point_builder (
        .measurement_time(system_ticks), .image_id(32'h5354524d),
        .line_id(16'd0), .point_id(point_id),
        .x_angle(16'sh0100), .y_angle(-16'sh0100),
        .i1(32'sd100000), .q1(-32'sd20000),
        .i2(32'sd12500), .q2(-32'sd2500),
        .a1(32'd101980), .a2(32'd12748),
        .flags(16'h0040), .config_revision(16'd1),
        .payload(point_payload)
    );

    wire source_word_valid;
    wire [31:0] source_word_data;
    wire source_word_last;
    wire source_block_done;
    wire source_word_ready;
    wire fifo_full;
    usb_fused_point_block_source source (
        .clk(clk120m), .rst(!locked),
        .point_valid(point_request), .point_payload(point_payload),
        .point_ready(point_ready), .word_valid(source_word_valid),
        .word_data(source_word_data), .word_last(source_word_last),
        .word_ready(source_word_ready), .busy(), .block_done(source_block_done),
        .frame_too_long()
    );

    // Keep the serializer continuously ready.  The vendor HSPI transmitter
    // needs one FIFO prefetch cycle, so delay the source by one word and write
    // word zero twice.  For this fixed 61-byte FUSED_POINT frame the discarded
    // final source word is guaranteed to contain only zero padding.
    reg [31:0] previous_source_word;
    reg previous_word_valid;
    wire [31:0] fifo_write_data = previous_word_valid ?
                                  previous_source_word : source_word_data;
    wire fifo_write_enable = source_word_valid && source_word_ready;
    assign source_word_ready = !fifo_full;

    always @(posedge clk120m or negedge locked) begin
        if (!locked) begin
            previous_source_word <= 32'd0;
            previous_word_valid <= 1'b0;
        end else if (point_request && point_ready) begin
            previous_source_word <= 32'd0;
            previous_word_valid <= 1'b0;
        end else if (source_word_valid && source_word_ready) begin
            previous_source_word <= source_word_data;
            previous_word_valid <= 1'b1;
        end
    end

    wire fifo_empty;
    wire transmitter_fifo_rd_en;
    wire fifo_rd_en;
    wire [31:0] fifo_dout;
    fifo_generator_0 stream_fifo (
        .rst(!locked), .wr_clk(clk120m), .rd_clk(clk30m),
        // Entries are word0, word0, word1, ..., word1022. The explicit TX
        // prefetch consumes the first copy; the final all-zero word1023 is
        // accepted by the source but intentionally not stored.
        .din(fifo_write_data), .wr_en(fifo_write_enable),
        .rd_en(fifo_rd_en), .dout(fifo_dout),
        .full(fifo_full), .empty(fifo_empty),
        .wr_rst_busy(), .rd_rst_busy()
    );

    reg block_ready_latched;
    always @(posedge clk120m or negedge locked) begin
        if (!locked)
            block_ready_latched <= 1'b0;
        else if (source_block_done)
            block_ready_latched <= 1'b1;
        else if (!tx_ctrl_r2)
            block_ready_latched <= 1'b0;
    end

    reg block_ready_r1;
    reg block_ready_r2;
    reg block_ready_r3;
    reg prefetch_read;
    reg [1:0] prefetch_delay;
    reg tx_enable;
    assign fifo_rd_en = prefetch_read || transmitter_fifo_rd_en;

    always @(posedge clk30m or negedge locked) begin
        if (!locked) begin
            block_ready_r1 <= 1'b0;
            block_ready_r2 <= 1'b0;
            block_ready_r3 <= 1'b0;
            prefetch_read <= 1'b0;
            prefetch_delay <= 2'd0;
            tx_enable <= 1'b0;
        end else begin
            block_ready_r1 <= block_ready_latched;
            block_ready_r2 <= block_ready_r1;
            block_ready_r3 <= block_ready_r2;
            prefetch_read <= 1'b0;
            tx_enable <= 1'b0;

            if (block_ready_r2 && !block_ready_r3) begin
                // The vendor standard-mode FIFO does not expose its first word
                // until one rd_en edge. Prefetch it before starting HSPI_Tx.
                prefetch_read <= 1'b1;
                prefetch_delay <= 2'd2;
            end else if (prefetch_delay != 0) begin
                prefetch_delay <= prefetch_delay - 1'b1;
                if (prefetch_delay == 2'd1)
                    tx_enable <= 1'b1;
            end
        end
    end

    wire [31:0] tx_data;
    HSPI_Tx transmitter (
        .Clk(clk30m), .Rst_n(locked), .Tx_En(tx_enable),
        .FIFO_EMPTY(fifo_empty), .FIFO_DOUT(fifo_dout),
        .FIFO_RD_EN(transmitter_fifo_rd_en), .HTCLK(HTCLK), .HTREQ(HTREQ),
        .HTRDY(HTRDY), .HTVLD(HTVLD), .HTD(tx_data)
    );

    genvar bit_index;
    generate
        for (bit_index = 0; bit_index < 32; bit_index = bit_index + 1) begin : hd_iobuf
            IOBUF hd_buffer (
                .O(), .IO(HD[bit_index]), .I(tx_data[bit_index]),
                .T(!(HTREQ && !HRACT))
            );
        end
    endgenerate

    // Inputs retained for pin compatibility with the validated loopback XDC.
    wire unused_inputs = HRCLK ^ HRVLD ^ Rx_Ctrl;
endmodule
