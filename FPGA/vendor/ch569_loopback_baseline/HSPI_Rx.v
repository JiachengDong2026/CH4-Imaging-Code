`timescale 1ns / 1ps


module HSPI_Rx(
    input                               Clk                        ,
    input                               Rst_n                      ,
    input                               Rx_En                      ,
    //FIFO WRITE 接口
    input                               FIFO_FULL                  ,
    output reg         [  31: 0]        FIFO_DIN                   ,
    output reg                          FIFO_WR_EN                 ,
    input                               FIFO_BUSY                  ,
    //HSPI Rx 接口
    input                               HRCLK                      ,
    input                               HRVLD                      ,
    input                               HRACT                      ,
    output reg                          HTACK                      ,
    input              [  31: 0]        HRD                        ,
    output reg                          Rx_Done                     
);

    reg                [  31: 0]        Head_Data                   ;
    reg                [  31: 0]        Tail_Data                   ;
    reg                [  15: 0]        Recv_Cnt                    ;
    reg                                 Rx_Start                    ;

    reg                [   3: 0]        SM_State                    ;
    localparam                          S_IDLE                     = 4'b0001;
    localparam                          S_HEAD                     = 4'b0010;
    localparam                          S_DATA                     = 4'b0100;
    localparam                          S_TAIL                     = 4'b1000;

//Rx_En启动传输
always @(posedge HRCLK or negedge Rst_n)
begin
    if(~Rst_n)
        Rx_Start <= 1'b0;
    else if(Rx_En && SM_State == S_IDLE)
        Rx_Start <= 1'b1;
    else if(SM_State == S_HEAD)
        Rx_Start <= 1'b0;
    else
        Rx_Start <= Rx_Start;
end

//状态机
always @(posedge HRCLK or negedge Rst_n) begin
    if(~Rst_n) begin
        SM_State <= S_IDLE;
        FIFO_DIN <= 32'h0000_0000;
        FIFO_WR_EN <= 1'b0;
        HTACK <= 1'b0;
        Recv_Cnt <= 16'd0;
        Head_Data <= 32'h0000_0000;
        Tail_Data <= 32'h0000_0000;
        Rx_Done <= 1'b0;
    end
    else begin
        case (SM_State)
            S_IDLE: begin
                HTACK <= 1'b0;
                Rx_Done <= 1'b0;
                if(Rx_Start & (~FIFO_FULL) & (~FIFO_BUSY)) begin
                    if(HRACT) begin
                        HTACK <= 1'b1;
                        SM_State <= S_HEAD;
                    end
                end
                else
                    SM_State <= S_IDLE;
            end
            S_HEAD: begin
                if(HRVLD) begin
                    Head_Data <= HRD;
                    SM_State <= S_DATA;
                end
                else
                    SM_State <= S_HEAD;
            end
            S_DATA: begin
                if((Recv_Cnt <= 16'd1023) & HRVLD) begin
                    Recv_Cnt <= Recv_Cnt + 1'b1;
                    FIFO_DIN <= HRD;
                    FIFO_WR_EN <= 1'b1;
                    if(Recv_Cnt == 16'd1023)
                        SM_State <= S_TAIL;
                end
                else begin
                    SM_State <= S_DATA;
                    FIFO_WR_EN <= 1'b0;
                    Recv_Cnt <= Recv_Cnt;
                end
            end
            S_TAIL: begin
                if(HRVLD) begin
                    Rx_Done <= 1'b1;
                    FIFO_WR_EN <= 1'b0;
                    FIFO_DIN <= 32'h0000_0000;
                    Recv_Cnt <= 16'd0;
                    Tail_Data <= HRD;
                    SM_State <= S_IDLE;
                end
            end
            default: SM_State <= S_IDLE;
        endcase
    end
end

`ifdef HSPI_DEBUG_ILA
ila_1 ila_1 (
    .clk                                (HRCLK                     ),// input wire clk
    .probe0                             (HRD                       ),// input wire [31:0]  probe0  
    .probe1                             (FIFO_DIN                  ),// input wire [31:0]  probe1 
    .probe2                             (Rx_En                     ),// input wire [0:0]  probe2 
    .probe3                             (Rx_Done                   ),// input wire [0:0]  probe3 
    .probe4                             (FIFO_FULL                 ),// input wire [0:0]  probe4 
    .probe5                             (HRVLD                     ),// input wire [0:0]  probe5 
    .probe6                             (HRACT                     ),// input wire [0:0]  probe6 
    .probe7                             (FIFO_WR_EN                ),// input wire [0:0]  probe7 
    .probe8                             (HTACK                     ) // input wire [0:0]  probe8
);
`endif

endmodule
