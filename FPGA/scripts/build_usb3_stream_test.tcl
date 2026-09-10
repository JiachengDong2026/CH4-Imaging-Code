set root [file normalize [file join [file dirname [info script]] .. ..]]
set fpga_root [file join $root FPGA]
set work [file join $fpga_root build usb3_stream_test]
set baseline [file join $fpga_root vendor ch569_loopback_baseline]
file mkdir $work
create_project ch4_usb3_stream_test $work -part xc7a200tfbg484-2 -force

set_property include_dirs [list [file join $fpga_root rtl protocol]] [current_fileset]
read_verilog [list \
 [file join $fpga_root rtl protocol protocol_defs.vh] \
 [file join $fpga_root rtl transport app_frame_serializer.v] \
 [file join $fpga_root rtl fusion fused_point_builder.v] \
 [file join $fpga_root rtl usb usb_hspi_block_packer.v] \
 [file join $fpga_root rtl usb usb_fused_point_block_source.v] \
 [file join $baseline crc32_32b.v] \
 [file join $baseline HSPI_Tx.v] \
 [file join $fpga_root rtl top ch4_usb3_stream_test_top.v]]
read_ip [file join $baseline clk_wiz_0 clk_wiz_0.xci]
read_ip [file join $baseline fifo_generator_0 fifo_generator_0.xci]
generate_target all [get_ips]
synth_ip [get_ips]
read_xdc [file join $fpga_root constraints acx750_ch569_usb3_loopback.xdc]

synth_design -top ch4_usb3_stream_test_top -part xc7a200tfbg484-2
opt_design
place_design
route_design
set debug_cells [get_cells -hier -quiet -filter {REF_NAME =~ "ila*" || REF_NAME == "dbg_hub"}]
if {[llength $debug_cells] != 0} {error "USB3 stream image contains debug cells: $debug_cells"}
report_timing_summary -file [file join $work timing_summary.rpt]
report_drc -file [file join $work drc.rpt]
set worst [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
if {$worst < 0.0} {error "USB3 stream timing failed: WNS=$worst ns"}
write_bitstream -force [file join $work ch4_usb3_stream_test.bit]
puts "USB3_STREAM_TEST_BITSTREAM_PASS [file join $work ch4_usb3_stream_test.bit]"
close_project
