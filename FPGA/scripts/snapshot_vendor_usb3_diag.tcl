# Snapshot sticky HSPI progress flags from the stable-clock diagnostic ILA.
# This does not reprogram or reset either device.
set root [file normalize [file join [file dirname [info script]] .. ..]]
set probes_file [file join $root FPGA build usb3_loopback vendor_top.ltx]
set output_file [file join $root tmp vendor_usb3_diag_snapshot.csv]
if {[info exists ::env(USB3_PROBES_FILE)] && $::env(USB3_PROBES_FILE) ne ""} {
    set probes_file [file normalize $::env(USB3_PROBES_FILE)]
}
if {[info exists ::env(USB3_DIAG_CSV)] && $::env(USB3_DIAG_CSV) ne ""} {
    set output_file [file normalize $::env(USB3_DIAG_CSV)]
}
file mkdir [file dirname $output_file]

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
set device [lindex [get_hw_devices -filter {PART =~ "xc7a200t*"}] 0]
if {$device eq ""} { error "xc7a200t device not found" }
current_hw_device $device
set_property PROBES.FILE $probes_file $device
refresh_hw_device $device

set ila [lindex [get_hw_ilas -of_objects $device -filter {CELL_NAME =~ "*hspi_diag_ila*"}] 0]
if {$ila eq ""} { error "stable-clock diagnostic ILA not found" }
foreach probe [get_hw_probes -of_objects $ila] {
    set_property TRIGGER_COMPARE_VALUE "eq1'bX" $probe
}
set_property CONTROL.TRIGGER_CONDITION AND $ila
set_property CONTROL.TRIGGER_POSITION 32 $ila
set_property CONTROL.DATA_DEPTH 1024 $ila
run_hw_ila $ila
wait_on_hw_ila $ila
upload_hw_ila_data $ila
write_hw_ila_data -force -csv_file $output_file [get_hw_ila_data -of_objects $ila]
puts "USB3_DIAG_SNAPSHOT=$output_file"
close_hw_manager
