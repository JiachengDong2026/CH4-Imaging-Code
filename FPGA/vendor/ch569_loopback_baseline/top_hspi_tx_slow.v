`timescale 1ns / 1ps

// Diagnostic-only top level. It retains the vendor receive path and HSPI_Tx
// RTL, but clocks HSPI_Tx at 30 MHz instead of 120 MHz. This isolates the
// CH569 receive timing without modifying the vendor transmitter source.
module top_hspi_tx_slow(
    input Clk_50M_In,
    input Resetn,
    output Bitstream_Done,
    input HRACT,
    input HRCLK,
    input HRVLD,
    output HTACK,
    output HTCLK,
    input HTRDY,
    output HTREQ,
    output HTVLD,
    inout [31:0] HD,
    input Rx_Ctrl,
    input Tx_Ctrl,
    output led
);
    wire [31:0] HRD;
    wire [31:0] HTD;
    wire locked;
    wire clk120m;
    wire clk30m;
    reg [1:0] tx_clk_div;

    assign Bitstream_Done = locked;
    assign led = locked;

    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : iobuf_loop
            IOBUF iobuf_inst (
                // Never drive the shared bus while the CH569 receive
                // transaction is still active.  Once HRACT is released,
                // HTREQ owns the bus for header, payload and CRC.
                .O(HRD[i]), .IO(HD[i]), .I(HTD[i]), .T(!(HTREQ && !HRACT))
            );
        end
    endgenerate

    clk_wiz_0 clk_wiz_0_inst (
        .clk_out1(clk120m), .reset(~Resetn), .locked(locked),
        .clk_in1(Clk_50M_In)
    );

    // 120 MHz / 4 gives a 30 MHz clock with a 50% duty cycle.
    always @(posedge clk120m or negedge locked) begin
        if (!locked)
            tx_clk_div <= 2'b00;
        else
            tx_clk_div <= tx_clk_div + 1'b1;
    end
    BUFG tx_clk_30m_bufg (.I(tx_clk_div[1]), .O(clk30m));

    wire Rx_En;
    Stream_Ctrl stream_ctrl_rx (
        .Clk(clk120m), .Rst_n(locked), .HRCLK(HRCLK), .Rx_En(Rx_En),
        .Rx_Ctrl(Rx_Ctrl), .Tx_En(), .Tx_Ctrl(Tx_Ctrl)
    );

    // Tx_Ctrl is asserted by CH569 before it waits for a received frame.
    // Synchronize it into the divided transmitter-clock domain.
    reg tx_ctrl_r1;
    reg tx_ctrl_r2;
    reg tx_ctrl_r3;
    reg tx_start_pending;
    always @(posedge clk30m or negedge locked) begin
        if (!locked) begin
            tx_ctrl_r1 <= 1'b0;
            tx_ctrl_r2 <= 1'b0;
            tx_ctrl_r3 <= 1'b0;
            tx_start_pending <= 1'b0;
        end else begin
            tx_ctrl_r1 <= Tx_Ctrl;
            tx_ctrl_r2 <= tx_ctrl_r1;
            tx_ctrl_r3 <= tx_ctrl_r2;
            if (tx_ctrl_r2 & ~tx_ctrl_r3) begin
                // Hold the request until the asynchronous FIFO has become
                // non-empty and HSPI_Tx has actually claimed the bus.
                tx_start_pending <= 1'b1;
            end else if (tx_start_pending && HTREQ) begin
                tx_start_pending <= 1'b0;
            end
        end
    end
    wire Tx_En = tx_start_pending;

    wire FIFO_WRITE_FULL;
    wire FIFO_WR_RST_BUSY;
    wire FIFO_WRITE_WR_EN;
    wire [31:0] FIFO_WRITE_DIN;
    wire HSPI_RX_DONE;
    HSPI_Rx hspi_rx_inst (
        .Clk(clk120m), .Rst_n(locked), .Rx_En(Rx_En),
        .FIFO_FULL(FIFO_WRITE_FULL), .FIFO_DIN(FIFO_WRITE_DIN),
        .FIFO_WR_EN(FIFO_WRITE_WR_EN), .FIFO_BUSY(FIFO_WR_RST_BUSY),
        .HRCLK(HRCLK), .HRVLD(HRVLD), .HRACT(HRACT), .HTACK(HTACK),
        .HRD(HRD), .Rx_Done(HSPI_RX_DONE)
    );

    // Remember completion of the full 1024-word receive frame, then
    // synchronize it into the transmitter clock domain.  This prevents a
    // Tx_Ctrl edge from starting a read while the FIFO is still being filled.
    reg rx_done_latched;
    always @(posedge HRCLK or negedge locked) begin
        if (!locked)
            rx_done_latched <= 1'b0;
        else if (HSPI_RX_DONE)
            rx_done_latched <= 1'b1;
    end

    reg rx_done_tx_r1;
    reg rx_done_tx_r2;
    always @(posedge clk30m or negedge locked) begin
        if (!locked) begin
            rx_done_tx_r1 <= 1'b0;
            rx_done_tx_r2 <= 1'b0;
        end else begin
            rx_done_tx_r1 <= rx_done_latched;
            rx_done_tx_r2 <= rx_done_tx_r1;
        end
    end

    wire FIFO_READ_EMPTY;
    wire FIFO_READ_RD_EN;
    wire [31:0] FIFO_READ_DOUT;
    fifo_generator_0 fifo_inst (
        .rst(!locked), .wr_clk(HRCLK), .rd_clk(clk30m),
        .din(FIFO_WRITE_DIN), .wr_en(FIFO_WRITE_WR_EN),
        .rd_en(FIFO_READ_RD_EN), .dout(FIFO_READ_DOUT),
        .full(FIFO_WRITE_FULL), .empty(FIFO_READ_EMPTY),
        .wr_rst_busy(FIFO_WR_RST_BUSY), .rd_rst_busy()
    );

    HSPI_Tx hspi_tx_inst (
        .Clk(clk30m), .Rst_n(locked), .Tx_En(Tx_En && rx_done_tx_r2),
        .FIFO_EMPTY(FIFO_READ_EMPTY), .FIFO_DOUT(FIFO_READ_DOUT),
        .FIFO_RD_EN(FIFO_READ_RD_EN), .HTCLK(HTCLK), .HTREQ(HTREQ),
        .HTRDY(HTRDY), .HTVLD(HTVLD), .HTD(HTD)
    );
endmodule
