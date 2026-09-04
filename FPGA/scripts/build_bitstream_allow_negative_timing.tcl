set root [file normalize [file join [file dirname [info script]] .. ..]]
set fpga_root [file join $root FPGA]
set output_dir [file join $fpga_root build bitstream]
file mkdir $output_dir
cd $output_dir

create_project -in_memory -part xc7a200tfbg484-2
set rtl [glob -nocomplain -directory [file join $fpga_root rtl] -types f */*.v]
read_verilog $rtl
set_property include_dirs [list [file join $fpga_root rtl protocol]] [current_fileset]
add_files -norecurse [file join $fpga_root data ch4_hitran_5000ppm.mem]
read_xdc [file join $fpga_root constraints acx750_ch569_stage0.xdc]
synth_design -top ch4_imaging_top -part xc7a200tfbg484-2
opt_design
place_design
phys_opt_design
route_design

report_utilization -file [file join $output_dir utilization.rpt]
report_timing_summary -delay_type max -max_paths 20 -file [file join $output_dir timing_summary.rpt]
report_drc -file [file join $output_dir drc.rpt]
report_io -file [file join $output_dir io.rpt]

set drc_errors [get_drc_violations -filter {SEVERITY == Error}]
if {[llength $drc_errors] > 0} {
    error "DRC contains [llength $drc_errors] error(s); see drc.rpt"
}

set timing_paths [get_timing_paths -delay_type max -max_paths 1]
if {[llength $timing_paths] > 0} {
    puts "FINAL_WNS=[get_property SLACK [lindex $timing_paths 0]]"
}
puts "WARNING: writing bitstream despite negative timing slack."
write_checkpoint -force [file join $output_dir ch4_imaging_routed.dcp]
write_bitstream -force [file join $output_dir ch4_imaging.bit]
puts "FPGA_STAGE1_BITSTREAM_WRITTEN"
close_design
