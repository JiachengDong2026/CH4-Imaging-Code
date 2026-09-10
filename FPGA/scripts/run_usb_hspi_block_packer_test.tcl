set root [file normalize [file join [file dirname [info script]] ../..]]
set out_dir [file join $root FPGA build usb_hspi_block_packer_sim]
file mkdir $out_dir
cd $out_dir

exec xvlog [file join $root FPGA rtl usb usb_hspi_block_packer.v] \
           [file join $root FPGA sim tb_usb_hspi_block_packer.v]
exec xelab tb_usb_hspi_block_packer -s usb_hspi_block_packer_sim
exec xsim usb_hspi_block_packer_sim -runall
