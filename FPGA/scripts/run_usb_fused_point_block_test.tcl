set root [file normalize [file join [file dirname [info script]] ../..]]
set out_dir [file join $root FPGA build usb_fused_point_block_sim]
file mkdir $out_dir
cd $out_dir

exec xvlog -i [file join $root FPGA rtl protocol] \
    [file join $root FPGA rtl protocol protocol_defs.vh] \
    [file join $root FPGA rtl transport app_frame_serializer.v] \
    [file join $root FPGA rtl usb usb_hspi_block_packer.v] \
    [file join $root FPGA rtl usb usb_fused_point_block_source.v] \
    [file join $root FPGA sim tb_usb_fused_point_block_source.v]
exec xelab tb_usb_fused_point_block_source -s usb_fused_point_block_sim
exec xsim usb_fused_point_block_sim -runall
