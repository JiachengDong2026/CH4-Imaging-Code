set root [file normalize [file join [file dirname [info script]] .. ..]]
set fpga_root [file join $root FPGA]
set work [file join $fpga_root build usb3_loopback]
set baseline [file join $fpga_root vendor ch569_loopback_baseline]
file mkdir $work
create_project ch4_usb3_loopback $work -part xc7a200tfbg484-2 -force
# The hardware baseline intentionally builds the exact vendor RX/TX/FIFO
# implementation that passed the physical 4096-byte loopback, plus the
# qualified 30 MHz/half-duplex wrapper.  The generic rtl/usb modules remain
# available for the later streaming redesign, but are not the golden baseline.
read_verilog [list \
 [file join $baseline Stream_Ctrl.v] \
 [file join $baseline HSPI_Rx.v] \
 [file join $baseline crc32_32b.v] \
 [file join $baseline HSPI_Tx.v] \
 [file join $baseline top_hspi_tx_slow.v]]
read_ip [file join $baseline clk_wiz_0 clk_wiz_0.xci]
read_ip [file join $baseline fifo_generator_0 fifo_generator_0.xci]
generate_target all [get_ips]
create_ip_run [get_ips]
synth_ip [get_ips]
read_xdc [file join $fpga_root constraints acx750_ch569_usb3_loopback.xdc]
synth_design -top top_hspi_tx_slow -part xc7a200tfbg484-2
opt_design
place_design
route_design
set debug_cells [get_cells -hier -quiet -filter {REF_NAME =~ "ila*" || REF_NAME == "dbg_hub"}]
if {[llength $debug_cells] != 0} {error "USB3 baseline contains debug cells: $debug_cells"}
report_timing_summary -file [file join $work timing_summary.rpt]
report_drc -file [file join $work drc.rpt]
set worst [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
if {$worst < 0.0} {error "USB3 loopback timing failed: WNS=$worst ns"}
write_bitstream -force [file join $work ch4_usb3_loopback.bit]
puts "USB3_LOOPBACK_BITSTREAM_PASS [file join $work ch4_usb3_loopback.bit]"
close_project
