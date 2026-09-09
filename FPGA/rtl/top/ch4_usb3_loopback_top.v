module ch4_usb3_loopback_top(
 input wire Clk_50M_In,input wire Resetn,output wire Bitstream_Done,
 input wire HRACT,input wire HRCLK,input wire HRVLD,output wire HTACK,
 output wire HTCLK,input wire HTRDY,output wire HTREQ,output wire HTVLD,inout wire[31:0]HD,
 input wire Rx_Ctrl,input wire Tx_Ctrl,output wire led
);
 wire clkfb,clkfb_buf,clk120_raw,clk120,clk30,locked;
 reg[1:0]tx_clk_div;
 MMCME2_BASE #(.BANDWIDTH("OPTIMIZED"),.CLKFBOUT_MULT_F(24.0),.DIVCLK_DIVIDE(1),.CLKOUT0_DIVIDE_F(10.0),.CLKIN1_PERIOD(20.0)) mmcm(
  .CLKIN1(Clk_50M_In),.CLKFBIN(clkfb_buf),.RST(!Resetn),.PWRDWN(1'b0),.CLKFBOUT(clkfb),.CLKOUT0(clk120_raw),.LOCKED(locked));
 BUFG fb_buf(.I(clkfb),.O(clkfb_buf));BUFG tx_clk_buf(.I(clk120_raw),.O(clk120));
 // The first hardware-qualified baseline uses 30 MHz HSPI TX.  Keep the
 // already proven 120 MHz MMCM configuration and divide it by four.
 always @(posedge clk120 or negedge locked)
  if(!locked)tx_clk_div<=2'b00;else tx_clk_div<=tx_clk_div+1'b1;
 BUFG tx_clk_30m_buf(.I(tx_clk_div[1]),.O(clk30));
 assign Bitstream_Done=locked;assign led=locked;
 wire rst=!locked;
 // HSPI diagnostic observations are deliberately sampled by clk120 rather
 // than HRCLK.  This keeps the ILA usable even when the CH569 does not start
 // its HSPI clock.  They do not alter the loopback data path.
 (* KEEP = "TRUE", MARK_DEBUG = "TRUE" *) reg dbg_rx_ctrl;
 (* KEEP = "TRUE", MARK_DEBUG = "TRUE" *) reg dbg_hreact;
 (* KEEP = "TRUE", MARK_DEBUG = "TRUE" *) reg dbg_hrclk_seen;
 (* KEEP = "TRUE", MARK_DEBUG = "TRUE" *) reg dbg_hrvld_seen;
 (* KEEP = "TRUE", MARK_DEBUG = "TRUE" *) reg dbg_htack_seen;
 reg hreact_meta,hrclk_meta,hrclk_sync,hrclk_prev,hrvld_meta,htack_meta;
 always @(posedge clk120 or posedge rst) begin
  if(rst) begin
   dbg_rx_ctrl<=0;dbg_hreact<=0;dbg_hrclk_seen<=0;dbg_hrvld_seen<=0;dbg_htack_seen<=0;
   hreact_meta<=0;hrclk_meta<=0;hrclk_sync<=0;hrclk_prev<=0;hrvld_meta<=0;htack_meta<=0;
  end else begin
   dbg_rx_ctrl<=Rx_Ctrl;
   hreact_meta<=HRACT; dbg_hreact<=hreact_meta;
   hrclk_meta<=HRCLK; hrclk_sync<=hrclk_meta; hrclk_prev<=hrclk_sync;
   hrvld_meta<=HRVLD; htack_meta<=HTACK;
   if(hrclk_sync!=hrclk_prev) dbg_hrclk_seen<=1'b1;
   if(hrvld_meta) dbg_hrvld_seen<=1'b1;
   if(htack_meta) dbg_htack_seen<=1'b1;
  end
 end
 reg rx_c1,rx_c2,rx_c3,tx_c1,tx_c2,tx_c3,tx_start_pending;
 always @(posedge HRCLK or posedge rst)if(rst)begin rx_c1<=0;rx_c2<=0;rx_c3<=0;end else begin rx_c1<=Rx_Ctrl;rx_c2<=rx_c1;rx_c3<=rx_c2;end
 // Tx_Ctrl can arrive before the asynchronous FIFO is visible in the TX
 // domain.  Latch the edge until the transmitter has claimed the bus.
 always @(posedge clk30 or posedge rst)if(rst)begin
  tx_c1<=0;tx_c2<=0;tx_c3<=0;tx_start_pending<=0;
 end else begin
  tx_c1<=Tx_Ctrl;tx_c2<=tx_c1;tx_c3<=tx_c2;
  if(tx_c2&&!tx_c3)tx_start_pending<=1'b1;
  else if(tx_start_pending&&HTREQ)tx_start_pending<=1'b0;
 end
 wire rx_enable=rx_c2&&!rx_c3;
 wire[31:0]hrd,htd;
 // HD is half duplex.  The FPGA must remain high impedance until CH569 has
 // released its receive transaction, even if HTREQ has already asserted.
 wire drive_bus=HTREQ&&!HRACT;genvar i;
 generate for(i=0;i<32;i=i+1)begin:io IOBUF b(.IO(HD[i]),.I(htd[i]),.O(hrd[i]),.T(!drive_bus));end endgenerate
 wire fifo_full,fifo_empty,fifo_wr_en,fifo_rd_en;wire[31:0]fifo_wr_data,fifo_rd_data;
 hspi_async_fifo fifo(.wr_clk(HRCLK),.wr_rst(rst),.wr_en(fifo_wr_en),.wr_data(fifo_wr_data),.full(fifo_full),
  .rd_clk(clk120),.rd_rst(rst),.rd_en(fifo_rd_en),.rd_data(fifo_rd_data),.empty(fifo_empty));
 wire rx_done,rx_overflow,tx_done,tx_underflow;
 hspi_loopback_rx rx(.rst_n(locked),.enable(rx_enable),.hrclk(HRCLK),.hrvld(HRVLD),.hract(HRACT),.hrd(hrd),.fifo_full(fifo_full),
  .htack(HTACK),.fifo_wr_en(fifo_wr_en),.fifo_wr_data(fifo_wr_data),.done(rx_done),.overflow(rx_overflow));
 // Do not start reading until the complete 1024-word RX payload is safely in
 // the FIFO.  The sticky flag mirrors the hardware-qualified vendor build.
 reg rx_done_latched,rx_done_tx_r1,rx_done_tx_r2;
 always @(posedge HRCLK or posedge rst)
  if(rst)rx_done_latched<=1'b0;else if(rx_done)rx_done_latched<=1'b1;
 always @(posedge clk30 or posedge rst)if(rst)begin
  rx_done_tx_r1<=1'b0;rx_done_tx_r2<=1'b0;
 end else begin
  rx_done_tx_r1<=rx_done_latched;rx_done_tx_r2<=rx_done_tx_r1;
 end
 hspi_loopback_tx tx(.clk(clk30),.rst_n(locked),.enable(tx_start_pending&&rx_done_tx_r2),.htrdy(HTRDY),.fifo_empty(fifo_empty),.fifo_data(fifo_rd_data),
  .htclk(HTCLK),.htreq(HTREQ),.htvld(HTVLD),.htd(htd),.fifo_rd_en(fifo_rd_en),.done(tx_done),.underflow(tx_underflow));
endmodule
