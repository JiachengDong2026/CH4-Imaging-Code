set root [file normalize [file join [file dirname [info script]] .. ..]]
set fpga_root [file join $root FPGA]
set work [file join $fpga_root build fast_mirror_sim]
file mkdir $work
create_project fast_mirror_sim $work -part xc7a200tfbg484-2 -force
read_verilog [file join $fpga_root rtl control fast_mirror_link.v]
add_files -fileset sim_1 [file join $fpga_root sim tb_fast_mirror_link.v]
set_property top tb_fast_mirror_link [get_filesets sim_1]
set_property simulator_language Verilog [current_project]
set_property xsim.simulate.runtime all [get_filesets sim_1]
launch_simulation
close_sim
close_project
set sim_log [file join $work fast_mirror_sim.sim sim_1 behav xsim simulate.log]
if {![file exists $sim_log]} {error "fast-mirror simulation log was not created"}
set handle [open $sim_log r]
set sim_text [read $handle]
close $handle
if {[string first "FAST_MIRROR_LINK_PASS" $sim_text] < 0} {error "fast-mirror link simulation did not report PASS; see $sim_log"}
puts "FAST_MIRROR_LINK_SIM_PASS"
