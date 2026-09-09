`timescale 1ns / 1ps

module Stream_Ctrl(
    input                               Clk                        ,
    input                               Rst_n                      ,
    input                               HRCLK                      ,
    output reg                          Rx_En                      ,
    input                               Rx_Ctrl                    ,
    output reg                          Tx_En                      ,
    input                               Tx_Ctrl                     
);

    reg                                 Tx_Ctrl_R1,Tx_Ctrl_R2,Tx_Ctrl_R3  ;
    reg                                 Rx_Ctrl_R1,Rx_Ctrl_R2,Rx_Ctrl_R3  ;

//对Tx_Ctrl打拍
always @(posedge Clk or negedge Rst_n)
begin
    if(~Rst_n) begin
        Tx_Ctrl_R1 <= 1'b0;
        Tx_Ctrl_R2 <= 1'b0;
        Tx_Ctrl_R3 <= 1'b0;
    end
    else begin
        Tx_Ctrl_R1 <= Tx_Ctrl;
        Tx_Ctrl_R2 <= Tx_Ctrl_R1;
        Tx_Ctrl_R3 <= Tx_Ctrl_R2;
    end
end


//根据输入的IO电平，启动Tx发送
always @(posedge Clk or negedge Rst_n)
begin
    if(~Rst_n)
        Tx_En <= 1'b0;
    else if((~Tx_Ctrl_R3) & Tx_Ctrl_R2)
        Tx_En <= 1'b1;
    else
        Tx_En <= 1'b0;
end

//对Rx_Ctrl打拍
always @(posedge HRCLK or negedge Rst_n)
begin
    if(~Rst_n) begin
        Rx_Ctrl_R1 <= 1'b0;
        Rx_Ctrl_R2 <= 1'b0;
        Rx_Ctrl_R3 <= 1'b0;
    end
    else begin
        Rx_Ctrl_R1 <= Rx_Ctrl;
        Rx_Ctrl_R2 <= Rx_Ctrl_R1;
        Rx_Ctrl_R3 <= Rx_Ctrl_R2;
    end
end

//根据输入的IO电平，启动Rx接收
always @(posedge HRCLK or negedge Rst_n)
begin
    if(~Rst_n)
        Rx_En <= 1'b0;
    else if((~Rx_Ctrl_R3) & Rx_Ctrl_R2)
        Rx_En <= 1'b1;
    else
        Rx_En <= 1'b0;
end


endmodule
