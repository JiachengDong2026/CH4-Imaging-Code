set root [file normalize [file join [file dirname [info script]] ../..]]
set fpga [file join $root FPGA]
set work [file join $fpga build usb3_imaging_stream]
set vendor [file join $fpga vendor ch569_loopback_baseline]
file mkdir $work
create_project ch4_usb3_imaging_stream $work -part xc7a200tfbg484-2 -force
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
# The 50 MHz imaging domain and MMCM 120 MHz USB packer domain exchange data
# only through hspi_async_fifo Gray-pointer synchronization.
set_clock_groups -asynchronous \
 -group [get_clocks sys_clk] \
 -group [get_clocks clk_out1_clk_wiz_0]
opt_design
place_design
route_design
report_timing_summary -file [file join $work timing_summary.rpt]
report_drc -file [file join $work drc.rpt]
set worst [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
if {$worst < 0.0} {error "USB3 imaging stream timing failed: WNS=$worst ns"}
write_bitstream -force [file join $work ch4_usb3_imaging_stream.bit]
puts "USB3_IMAGING_STREAM_BITSTREAM_PASS [file join $work ch4_usb3_imaging_stream.bit]"
close_project
