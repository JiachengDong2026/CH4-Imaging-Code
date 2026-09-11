set root [file normalize [file join [file dirname [info script]] ../..]]
set out_dir [file join $root FPGA build usb_fused_point_stream_bridge_sim]
file mkdir $out_dir
cd $out_dir
exec xvlog -i [file join $root FPGA rtl protocol] \
    [file join $root FPGA rtl protocol protocol_defs.vh] \
    [file join $root FPGA rtl transport app_frame_serializer.v] \
    [file join $root FPGA rtl usb hspi_async_fifo.v] \
    [file join $root FPGA rtl usb usb_hspi_block_packer.v] \
    [file join $root FPGA rtl usb usb_fused_point_block_source.v] \
    [file join $root FPGA rtl usb usb_fused_point_multi_block_source.v] \
    [file join $root FPGA rtl usb usb_fused_point_stream_bridge.v] \
    [file join $root FPGA sim tb_usb_fused_point_stream_bridge.v]
exec xelab tb_usb_fused_point_stream_bridge -s usb_fused_point_stream_bridge_sim
set result [exec xsim usb_fused_point_stream_bridge_sim -runall]
puts $result
if {[string first "USB_FUSED_POINT_STREAM_BRIDGE_PASS" $result] < 0} {
    error "USB fused-point stream bridge test did not report PASS"
}
