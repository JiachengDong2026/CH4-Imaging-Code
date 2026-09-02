set root [file normalize [file join [file dirname [info script]] .. ..]]
set fpga_root [file join $root FPGA]
set project_dir [file join $fpga_root vivado ch4_imaging]
file mkdir $project_dir
create_project ch4_imaging $project_dir -part xc7a200tfbg484-2 -force

set rtl [glob -nocomplain -directory [file join $fpga_root rtl] -types f */*.v]
read_verilog $rtl
set_property include_dirs [list [file join $fpga_root rtl protocol]] [current_fileset]
read_xdc [file join $fpga_root constraints acx750_ch569_stage0.xdc]
set_property top ch4_imaging_top [current_fileset]
update_compile_order -fileset sources_1
puts "CH4_STAGE0_PROJECT_CREATED $project_dir"

