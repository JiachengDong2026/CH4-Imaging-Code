set root [file normalize [file join [file dirname [info script]] .. ..]]
set fpga_root [file join $root FPGA]
set work [file join $fpga_root build usb3_hspi_diagnostic]
file mkdir $work
create_project ch4_usb3_hspi_diagnostic $work -part xc7a200tfbg484-2 -force
read_verilog [glob -directory [file join $fpga_root rtl usb] *.v]
read_verilog [file join $fpga_root rtl top ch4_usb3_loopback_top.v]
read_xdc [file join $fpga_root constraints acx750_ch569_usb3_loopback.xdc]
synth_design -top ch4_usb3_loopback_top -part xc7a200tfbg484-2

# This ILA is clocked by the FPGA's local 120 MHz clock, not HRCLK.
create_debug_core hspi_diag_ila ila
set_property C_DATA_DEPTH 8192 [get_debug_cores hspi_diag_ila]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores hspi_diag_ila]
connect_debug_port hspi_diag_ila/clk [get_nets clk120]
set probe_index 0
foreach signal {dbg_rx_ctrl dbg_hreact dbg_hrclk_seen dbg_hrvld_seen dbg_htack_seen} {
 create_debug_port hspi_diag_ila probe
 set probe [get_debug_ports hspi_diag_ila/probe$probe_index]
 set_property PROBE_TYPE DATA_AND_TRIGGER $probe
 connect_debug_port $probe [get_nets $signal]
 incr probe_index
}

opt_design
place_design
route_design
report_timing_summary -file [file join $work timing_summary.rpt]
report_drc -file [file join $work drc.rpt]
write_debug_probes -force [file join $work ch4_usb3_hspi_diagnostic.ltx]
write_bitstream -force [file join $work ch4_usb3_hspi_diagnostic.bit]
puts "USB3_HSPI_DIAGNOSTIC_BITSTREAM_PASS [file join $work ch4_usb3_hspi_diagnostic.bit]"
close_project
