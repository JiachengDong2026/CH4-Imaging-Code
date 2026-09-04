set root [file normalize [file join [file dirname [info script]] .. ..]]
set fpga_root [file join $root FPGA]
set work [file join $fpga_root build uart_comm_sim]
file mkdir $work
cd $root
create_project ch4_uart_comm_sim $work -part xc7a200tfbg484-2 -force
set rtl [glob -nocomplain -directory [file join $fpga_root rtl] -types f */*.v]
read_verilog $rtl
set_property include_dirs [list [file join $fpga_root rtl protocol]] [current_fileset]
add_files -fileset sim_1 [file join $fpga_root sim tb_uart_comm_test_top.v]
set_property top tb_uart_comm_test_top [get_filesets sim_1]
set_property simulator_language Verilog [current_project]
set_property xsim.simulate.runtime all [get_filesets sim_1]
launch_simulation
close_sim
close_project
set sim_log [file join $work ch4_uart_comm_sim.sim sim_1 behav xsim simulate.log]
if {![file exists $sim_log]} {error "UART communication simulation log was not created"}
set handle [open $sim_log r]
set sim_text [read $handle]
close $handle
if {[string first "FPGA_UART_COMM_TEST_PASS" $sim_text] < 0} {error "UART communication simulation did not report PASS; see $sim_log"}
puts "FPGA_UART_COMM_SIM_PASS"
