`include "protocol_defs.vh"

module ch4_imaging_top #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer UART_BAUD = 921600
)(
    input wire sys_clk,
    input wire sys_rst_n,
    input wire uart_rxd,
    output wire uart_txd
);
    wire rst;
    wire [63:0] system_ticks;
    wire uart_byte_valid;
    wire [7:0] uart_byte;
    wire uart_framing_error;
    wire app_frame_valid;
    wire app_frame_error;
    wire app_crc_error;
    wire app_length_error;
    wire app_version_error;
    wire [7:0] app_version, app_dst, app_src, app_type, app_flags;
    wire [15:0] app_sequence, app_payload_length;

    reset_sync reset_sync_i(.clk(sys_clk), .arst_n(sys_rst_n), .srst(rst));
    system_timebase timebase_i(.clk(sys_clk), .rst(rst), .ticks(system_ticks));
    uart_rx #(.CLK_HZ(CLOCK_HZ), .BAUD(UART_BAUD)) uart_rx_i(
        .clk(sys_clk), .rst(rst), .rx(uart_rxd), .valid(uart_byte_valid),
        .data(uart_byte), .framing_error(uart_framing_error));
    app_frame_rx frame_rx_i(
        .clk(sys_clk), .rst(rst), .byte_valid(uart_byte_valid), .byte_data(uart_byte),
        .frame_valid(app_frame_valid), .frame_error(app_frame_error),
        .crc_error(app_crc_error), .length_error(app_length_error),
        .version_error(app_version_error), .frame_version(app_version),
        .frame_dst(app_dst), .frame_src(app_src), .frame_type(app_type),
        .frame_flags(app_flags), .frame_sequence(app_sequence),
        .frame_payload_length(app_payload_length));

    // The command engine and response serializer are stage 1 work. Keep the
    // UART idle high so this stage-0 bitstream is electrically safe.
    assign uart_txd = 1'b1;
endmodule

