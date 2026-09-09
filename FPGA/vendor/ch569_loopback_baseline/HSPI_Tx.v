`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/02/10 17:25:38
// Design Name: 
// Module Name: HSPI_Tx
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module HSPI_Tx(
    input                               Clk                        ,
    input                               Rst_n                      ,
    input                               Tx_En                      ,
    //FIFO READ 接口
    input                               FIFO_EMPTY            ,
    input              [  31: 0]        FIFO_DOUT             ,
    output reg                          FIFO_RD_EN            ,
    //HSPI Tx 接口
    output                              HTCLK                      ,
    output reg                          HTREQ                      ,
    input                               HTRDY                      ,
    output reg                          HTVLD                      ,
    output reg         [  31: 0]        HTD                         
);

    localparam                          Tx_Length_Low              = 2'b11 ;
    // Keep the vendor frame marker on the wire and include the exact transmitted
    // header in the CRC, matching the original vendor implementation.
    localparam                          User_Define_Data           = 26'b1010_1010_1010_1010_1010_1010_10;

    reg                [   3: 0]        Tx_Num_Sequence             ;
    reg                                 Tx_Start,Tx_Done,Tx_Done_R  ;
    reg                [  31: 0]        Tx_Data                     ;
    reg                                 Data_Valid                  ;
    reg                                 HTRDY_R1,HTRDY_R2,HTRDY_R3  ;
    reg                [  31: 0]        Cnt                         ;
    wire               [  31: 0]        CRC_32D                     ;
//assign HTREQ = Tx_Start;

    reg                [   3: 0]        SM_State                    ;
    localparam                          S_IDLE                     = 4'b0001;
    localparam                          S_HEAD                     = 4'b0010;
    localparam                          S_DATA                     = 4'b0100;
    localparam                          S_TAIL                     = 4'b1000;

//assign HTD = Tx_Data;//(SM_State == S_TAIL) ? CRC_32D : Tx_Data;
    assign                              HTCLK                       = Clk;


always @(posedge Clk or negedge Rst_n)
begin
    if(~Rst_n)
        Cnt <= 32'd0;
    else if(SM_State == S_DATA)
        Cnt <= Cnt + 1'b1;
    else
        Cnt <= 32'd0;
end

//Tx_En启动传输

always @(posedge Clk or negedge Rst_n)
begin
    if(~Rst_n)
        Tx_Start <= 1'b0;
    else if(Tx_En && SM_State == S_IDLE)
        Tx_Start <= 1'b1;
    else if(SM_State == S_HEAD)
        Tx_Start <= 1'b0;
    else
        Tx_Start <= Tx_Start;
end

    wire               [  31: 0]        wire_crc_data               ;
    wire               [  31: 0]        wire_crc_in                 ;
    wire               [  31: 0]        wire_crc_out32              ;
    wire                                wire_tx_crc_clr             ;
    wire                                wire_crc_en                 ;

//tx crc
    assign                              wire_tx_crc_clr             = (~Rst_n) | Tx_Done_R;//CRC module reset
    assign                              wire_crc_en                 = Data_Valid;//HTRDY & (SM_State == S_HEAD | SM_State == S_DATA);		//calculate CRC during header and data payload tx period
assign wire_crc_data = Tx_Data;
assign wire_crc_in  =  {wire_crc_data[0 ], wire_crc_data[1 ], wire_crc_data[2 ], wire_crc_data[3 ],
                        wire_crc_data[4 ], wire_crc_data[5 ], wire_crc_data[6 ], wire_crc_data[7 ],
                        wire_crc_data[8 ], wire_crc_data[9 ], wire_crc_data[10], wire_crc_data[11],
                        wire_crc_data[12], wire_crc_data[13], wire_crc_data[14], wire_crc_data[15],
                        wire_crc_data[16], wire_crc_data[17], wire_crc_data[18], wire_crc_data[19],
                        wire_crc_data[20], wire_crc_data[21], wire_crc_data[22], wire_crc_data[23],
                        wire_crc_data[24], wire_crc_data[25], wire_crc_data[26], wire_crc_data[27],
                        wire_crc_data[28], wire_crc_data[29], wire_crc_data[30], wire_crc_data[31]
                        };
assign CRC_32D =    {~wire_crc_out32[0], ~wire_crc_out32[1], ~wire_crc_out32[2], ~wire_crc_out32[3], 
                    ~wire_crc_out32[4], ~wire_crc_out32[5], ~wire_crc_out32[6], ~wire_crc_out32[7],
                    ~wire_crc_out32[8], ~wire_crc_out32[9], ~wire_crc_out32[10], ~wire_crc_out32[11],
                    ~wire_crc_out32[12], ~wire_crc_out32[13], ~wire_crc_out32[14], ~wire_crc_out32[15],
                    ~wire_crc_out32[16], ~wire_crc_out32[17], ~wire_crc_out32[18], ~wire_crc_out32[19],
                    ~wire_crc_out32[20], ~wire_crc_out32[21], ~wire_crc_out32[22], ~wire_crc_out32[23],
                    ~wire_crc_out32[24], ~wire_crc_out32[25], ~wire_crc_out32[26], ~wire_crc_out32[27],
                    ~wire_crc_out32[28], ~wire_crc_out32[29], ~wire_crc_out32[30], ~wire_crc_out32[31]
                    };


crc32_32b m_crc32 (
    .clk                                (Clk                       ),
    .rst                                (wire_tx_crc_clr           ),
    .crc_en                             (wire_crc_en               ),
    .data_in                            (wire_crc_in               ),
    .crc_out                            (wire_crc_out32            ) 
);

//状态机发送数�?
always @(posedge Clk or negedge Rst_n)
begin
    if(~Rst_n) begin
        SM_State <= S_IDLE;
        Data_Valid <= 1'b0;
        Tx_Data <= 32'd0;
        Tx_Done <= 1'b0;
        Tx_Num_Sequence <= 4'd0;
        FIFO_RD_EN <= 1'b0;
    end
    else begin
        case (SM_State)
            S_IDLE: begin
                if (Tx_Start & (~FIFO_EMPTY)) begin
                    SM_State <= S_HEAD;
                    HTREQ <= 1'b1;
                end
                else if(~Tx_Done) begin
                    SM_State <= S_IDLE;
                    HTREQ <= 1'b0;
                end
                else begin
                    SM_State <= S_IDLE;
                end
                Tx_Done <= 1'b0;
                Data_Valid <= 1'b0;
            end
            S_HEAD: begin
                Tx_Data <= {Tx_Length_Low,Tx_Num_Sequence,User_Define_Data};
                //读fifo需要提前准�?
                if(HTRDY_R2)
                    FIFO_RD_EN <= 1'b1;
                if(HTRDY_R3) begin
                    Data_Valid <= 1'b1;
                    if(Tx_Num_Sequence == 4'd15)
                        Tx_Num_Sequence <= 4'd0;
                    else
                        Tx_Num_Sequence <= Tx_Num_Sequence + 1'b1;
                    SM_State <= S_DATA;
                end
                else
                    SM_State <= S_HEAD;

            end
            S_DATA: begin
                Tx_Data <= FIFO_DOUT;
                Data_Valid <= 1'b1;
                //RD_EN提前两拍开始，提前两拍结束
                if(Cnt == 32'd1022) begin
                    FIFO_RD_EN <= 1'b0;
                end
                if(Cnt == 32'd1023) begin
                    SM_State <= S_TAIL;
                end
                else
                    SM_State <= S_DATA;
            end
            S_TAIL: begin                                           //计算32位crc校验
                Tx_Data <= CRC_32D;
                Data_Valid <= 1'b1;
                Tx_Done <= 1'b1;
                SM_State <= S_IDLE;
            end
            default: SM_State <= S_IDLE;
        endcase
    end
end

	
//Tx_Done打拍
always@(posedge Clk or negedge Rst_n)
if(~Rst_n)
    Tx_Done_R <= 0;
else
    Tx_Done_R <= Tx_Done;

//HTVLD打拍
always@(posedge Clk or negedge Rst_n)
if(~Rst_n)
    HTVLD <= 0;
else
    HTVLD <= Data_Valid;

//HTRDY打拍
always@(posedge Clk or negedge Rst_n)
if(~Rst_n) begin
    HTRDY_R1 <= 0;
    HTRDY_R2 <= 0;
    HTRDY_R3 <= 0;
end
    
else begin
    HTRDY_R1 <= HTRDY;
    HTRDY_R2 <= HTRDY_R1;
    HTRDY_R3 <= HTRDY_R2;
end
    

//HTD打拍
always@(posedge Clk or negedge Rst_n)
if(~Rst_n)
    HTD <= 0;
else if(Tx_Done)
    HTD <= CRC_32D;
else
    HTD <= Tx_Data;
    
`ifdef HSPI_DEBUG_ILA
ila_0 ila_0 (
    .clk                                (Clk                       ),// input wire clk
    .probe0                             (HTD                       ),// input wire [31:0]  probe0  
    .probe1                             (FIFO_DOUT            ),// input wire [31:0]  probe1 
    .probe2                             (Tx_En                     ),// input wire [0:0]  probe2 
    .probe3                             (FIFO_EMPTY           ),// input wire [0:0]  probe3 
    .probe4                             (HTRDY                     ),// input wire [0:0]  probe4 
    .probe5                             (FIFO_RD_EN           ),// input wire [0:0]  probe5 
    .probe6                             (HTREQ                     ),// input wire [0:0]  probe6 
    .probe7                             (HTVLD                     ),// input wire [0:0]  probe7 
    .probe8                             (Tx_Done                   ) // input wire [0:0]  probe8
);
`endif
endmodule

                                                         // crc
