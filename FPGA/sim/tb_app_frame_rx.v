`timescale 1ns/1ps
`include "protocol_defs.vh"

module tb_app_frame_rx;
    reg clk=0, rst=1, byte_valid=0;
    reg [7:0] byte_data=0;
    wire frame_valid, frame_error, crc_error, length_error, version_error;
    wire [7:0] frame_version, frame_dst, frame_src, frame_type, frame_flags;
    wire [15:0] frame_sequence, frame_payload_length;
    reg [7:0] hello_bytes[0:12];
    reg [7:0] write_bytes[0:20];
    reg [7:0] fused_bytes[0:60];
    integer i;
    integer valid_count=0;
    integer error_count=0;
    reg crc_error_seen=0;

    `include "generated_protocol_vectors.vh"

    always #10 clk=~clk;
    always @(posedge clk) begin
        if(frame_valid) valid_count=valid_count+1;
        if(frame_error) begin
            error_count=error_count+1;
            if(crc_error) crc_error_seen=1;
        end
    end

    app_frame_rx dut(
        .clk(clk),.rst(rst),.byte_valid(byte_valid),.byte_data(byte_data),
        .frame_valid(frame_valid),.frame_error(frame_error),.crc_error(crc_error),
        .length_error(length_error),.version_error(version_error),
        .frame_version(frame_version),.frame_dst(frame_dst),.frame_src(frame_src),
        .frame_type(frame_type),.frame_flags(frame_flags),.frame_sequence(frame_sequence),
        .frame_payload_length(frame_payload_length));

    task send_byte;
        input [7:0] value;
        begin
            @(negedge clk); byte_data=value; byte_valid=1;
            @(negedge clk); byte_valid=0;
        end
    endtask

    initial begin
        load_fixed_vectors();
        repeat(4) @(posedge clk); rst=0;

        send_byte(8'h00); send_byte(8'h7E); // leading garbage must be ignored
        for(i=0;i<13;i=i+1) send_byte(hello_bytes[i]);
        repeat(2) @(posedge clk);
        if(valid_count!=1 || frame_type!=`CH4_MSG_HELLO || frame_sequence!=16'h1234 || frame_payload_length!=0)
            $fatal(1,"HELLO vector failed");

        for(i=0;i<21;i=i+1) send_byte(write_bytes[i]);
        repeat(2) @(posedge clk);
        if(valid_count!=2 || frame_type!=`CH4_MSG_WRITE_REG || frame_payload_length!=8)
            $fatal(1,"WRITE_REG vector failed");

        for(i=0;i<61;i=i+1) send_byte(fused_bytes[i]);
        repeat(2) @(posedge clk);
        if(valid_count!=3 || frame_type!=`CH4_MSG_FUSED_POINT || frame_payload_length!=48)
            $fatal(1,"FUSED_POINT vector failed");

        for(i=0;i<12;i=i+1) send_byte(hello_bytes[i]);
        send_byte(hello_bytes[12]^8'h01);
        repeat(2) @(posedge clk);
        if(error_count!=1 || !crc_error_seen || valid_count!=3)
            $fatal(1,"bad CRC was not rejected");

        $display("FPGA_PROTOCOL_TEST_PASS valid=%0d errors=%0d",valid_count,error_count);
        $finish;
    end
endmodule
