set root [file normalize [file join [file dirname [info script]] .. ..]]
set fpga_root [file join $root FPGA]
set work [file join $fpga_root build usb3_loopback_sim]
file mkdir $work
cd $work
exec xvlog [file join $fpga_root rtl usb hspi_async_fifo.v] [file join $fpga_root rtl usb hspi_crc32_32.v] \
 [file join $fpga_root rtl usb hspi_loopback_rx.v] [file join $fpga_root rtl usb hspi_loopback_tx.v] \
 [file join $fpga_root sim tb_usb3_loopback.v]
exec xelab tb_usb3_loopback -s usb3_loopback_sim
set result [exec xsim usb3_loopback_sim -runall]
puts $result
if {[string first "USB3_LOOPBACK_PASS" $result] < 0} {error "USB3 loopback simulation failed"}
