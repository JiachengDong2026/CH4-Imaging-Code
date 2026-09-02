set root [file normalize [file join [file dirname [info script]] .. ..]]
set fpga_root [file join $root FPGA]
set work [file join $fpga_root build syntax]
file mkdir $work
create_project ch4_stage0_syntax $work -part xc7a200tfbg484-2 -force
set rtl [glob -nocomplain -directory [file join $fpga_root rtl] -types f */*.v]
read_verilog $rtl
set_property include_dirs [list [file join $fpga_root rtl protocol]] [current_fileset]
read_xdc [file join $fpga_root constraints acx750_ch569_stage0.xdc]
set_property top ch4_imaging_top [current_fileset]
update_compile_order -fileset sources_1
synth_design -top ch4_imaging_top -part xc7a200tfbg484-2
write_checkpoint -force [file join $work stage0_synth.dcp]
puts "FPGA_STAGE0_SYNTHESIS_PASS"
close_project
