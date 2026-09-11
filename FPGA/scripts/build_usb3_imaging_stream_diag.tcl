set root [file normalize [file join [file dirname [info script]] ../..]]
set fpga [file join $root FPGA]
set work [file join $fpga build usb3_imaging_stream_diag]
set vendor [file join $fpga vendor ch569_loopback_baseline]
file mkdir $work
create_project ch4_usb3_imaging_stream_diag $work -part xc7a200tfbg484-2 -force
set_property include_dirs [list [file join $fpga rtl protocol]] [current_fileset]
set rtl [glob -nocomplain -directory [file join $fpga rtl] -types f */*.v]
read_verilog $rtl
read_verilog [list [file join $vendor crc32_32b.v] [file join $vendor HSPI_Tx.v]]
read_ip [file join $vendor clk_wiz_0 clk_wiz_0.xci]
read_ip [file join $vendor fifo_generator_0 fifo_generator_0.xci]
generate_target all [get_ips]
synth_ip [get_ips]
add_files -norecurse [file join $fpga data ch4_hitran_5000ppm.mem]
read_xdc [file join $fpga constraints acx750_ch569_usb3_loopback.xdc]
synth_design -top ch4_usb3_imaging_stream_top -part xc7a200tfbg484-2
set_clock_groups -asynchronous -group [get_clocks sys_clk] -group [get_clocks clk_out1_clk_wiz_0]

create_debug_core usb_stream_ila ila
set_property C_DATA_DEPTH 4096 [get_debug_cores usb_stream_ila]
set_property C_ADV_TRIGGER false [get_debug_cores usb_stream_ila]
set_property port_width 32 [get_debug_ports usb_stream_ila/probe0]
connect_debug_port usb_stream_ila/clk [get_nets clk120m]
set debug_nets [lsort -dictionary [get_nets {usb_stream_debug[*]}]]
if {[llength $debug_nets] != 32} {error "expected 32 debug nets, got [llength $debug_nets]: $debug_nets"}
connect_debug_port usb_stream_ila/probe0 $debug_nets

opt_design
place_design
route_design
report_timing_summary -file [file join $work timing_summary.rpt]
write_debug_probes -force [file join $work ch4_usb3_imaging_stream_diag.ltx]
write_bitstream -force [file join $work ch4_usb3_imaging_stream_diag.bit]
puts "USB3_IMAGING_STREAM_DIAG_PASS [file join $work ch4_usb3_imaging_stream_diag.bit]"
close_project
