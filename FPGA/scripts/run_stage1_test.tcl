set root [file normalize [file join [file dirname [info script]] .. ..]]
set fpga_root [file join $root FPGA]
set work [file join $fpga_root build stage1_sim]
file mkdir $work
cd $root
create_project ch4_stage1_sim $work -part xc7a200tfbg484-2 -force
set rtl [glob -nocomplain -directory [file join $fpga_root rtl] -types f */*.v]
read_verilog $rtl
set_property include_dirs [list [file join $fpga_root rtl protocol]] [current_fileset]
add_files -norecurse [file join $fpga_root data ch4_hitran_5000ppm.mem]
add_files -fileset sim_1 [file join $fpga_root sim tb_stage1_dila.v]
set_property top tb_stage1_dila [get_filesets sim_1]
set_property simulator_language Verilog [current_project]
set_property xsim.simulate.runtime all [get_filesets sim_1]
launch_simulation
close_sim
close_project
set sim_log [file join $work ch4_stage1_sim.sim sim_1 behav xsim simulate.log]
if {![file exists $sim_log]} {error "stage-1 simulation log was not created"}
set handle [open $sim_log r]
set sim_text [read $handle]
close $handle
if {[string first "FPGA_STAGE1_DILA_PASS" $sim_text] < 0} {error "stage-1 DILA simulation did not report PASS; see $sim_log"}
puts "FPGA_STAGE1_SIM_PASS"
