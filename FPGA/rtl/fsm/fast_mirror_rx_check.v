`timescale 1ns / 1ps
// Reused from uart_bridge_v4. Parses the mirror's fixed 9-byte native frame.
module fast_mirror_rx_check(
    input wire clk,input wire rst_n,input wire [7:0] rx_data,input wire rx_valid,
    output reg sample_valid,output reg [7:0] feedback_code,
    output reg [15:0] x_angle_raw,output reg [15:0] y_angle_raw,
    output reg checksum_error,output reg [31:0] valid_count,output reg [31:0] error_count
);
    reg [3:0] count; reg [7:0] frame[0:8]; reg [7:0] check;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            count<=0; sample_valid<=0; feedback_code<=0; x_angle_raw<=0; y_angle_raw<=0;
            checksum_error<=0; valid_count<=0; error_count<=0; check<=0;
        end else begin
            sample_valid<=0; checksum_error<=0;
            if(rx_valid) begin
                case(count)
                    0: if(rx_data==8'h55) begin frame[0]<=rx_data; count<=1; end
                    1: if(rx_data==8'hAA) begin frame[1]<=rx_data; count<=2; end else count<=0;
                    2: begin frame[2]<=rx_data; count<=3; end
                    3: begin frame[3]<=rx_data; count<=4; end
                    4: begin frame[4]<=rx_data; count<=5; end
                    5: begin frame[5]<=rx_data; count<=6; end
                    6: begin frame[6]<=rx_data; count<=7;
                        check<=frame[2]^frame[3]^frame[4]^frame[5]^rx_data^8'hFF; end
                    7: begin frame[7]<=rx_data; count<=8; end
                    8: begin
                        frame[8]<=rx_data;
                        if(rx_data==8'hCC && frame[7]==check) begin
                            feedback_code<=frame[2]; x_angle_raw<={frame[3],frame[4]};
                            y_angle_raw<={frame[5],frame[6]}; sample_valid<=1; valid_count<=valid_count+1;
                        end else begin checksum_error<=1; error_count<=error_count+1; end
                        count<=0;
                    end
                    default: count<=0;
                endcase
            end
        end
    end
endmodule

