set root [file normalize [file join [file dirname [info script]] ../..]]
set out_dir [file join $root FPGA build usb_harmonic_multi_block_source_sim]
file mkdir $out_dir
set fpga [file join $root FPGA]
exec xvlog -i [file join $fpga rtl protocol] \
    [file join $fpga rtl protocol protocol_defs.vh] \
    [file join $fpga rtl transport app_frame_serializer.v] \
    [file join $fpga rtl usb usb_hspi_block_packer.v] \
    [file join $fpga rtl usb usb_harmonic_multi_block_source.v] \
    [file join $fpga sim tb_usb_harmonic_multi_block_source.v]
exec xelab tb_usb_harmonic_multi_block_source -s usb_harmonic_multi_block_source_sim
set result [exec xsim usb_harmonic_multi_block_source_sim -runall]
if {[string first "USB_HARMONIC_MULTI_BLOCK_PASS" $result] < 0} {error "harmonic multi-block source test failed"}
puts $result
