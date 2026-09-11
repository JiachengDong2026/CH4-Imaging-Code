# Capture an immediate post-reset snapshot from the real imaging-stream ILA.
set root [file normalize [file join [file dirname [info script]] ../..]]
set probes_file [file join $root FPGA build usb3_imaging_stream_diag ch4_usb3_imaging_stream_diag.ltx]
set output_file [file join $root tmp usb3_imaging_stream_diag_snapshot.csv]
file mkdir [file dirname $output_file]

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
set device [lindex [get_hw_devices -filter {PART =~ "xc7a200t*"}] 0]
if {$device eq ""} { error "xc7a200t device not found" }
current_hw_device $device
set_property PROBES.FILE $probes_file $device
set_property FULL_PROBES.FILE $probes_file $device
refresh_hw_device $device

set ila [lindex [get_hw_ilas -of_objects $device -filter {CELL_NAME =~ "*usb_stream_ila*"}] 0]
if {$ila eq ""} { error "usb_stream_ila not found" }
set probe [lindex [get_hw_probes -of_objects $ila -filter {NAME =~ "*usb_stream_debug*"}] 0]
if {$probe eq ""} { error "usb_stream_debug probe not found" }
set_property TRIGGER_COMPARE_VALUE "eq32'hXXXX_XXXX" $probe
set_property CONTROL.TRIGGER_CONDITION AND $ila
set_property CONTROL.TRIGGER_POSITION 32 $ila
set_property CONTROL.DATA_DEPTH 4096 $ila
run_hw_ila $ila
wait_on_hw_ila $ila
upload_hw_ila_data $ila
write_hw_ila_data -force -csv_file $output_file [get_hw_ila_data -of_objects $ila]
puts "USB3_IMAGING_SNAPSHOT=$output_file"
close_hw_manager
