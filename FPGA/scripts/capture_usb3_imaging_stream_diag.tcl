# Capture the real imaging-stream HSPI transaction around CH569 Tx_Ctrl.
# probe0 is usb_stream_debug[31:0]; Tx_Ctrl is bit 6.
set root [file normalize [file join [file dirname [info script]] ../..]]
set probes_file [file join $root FPGA build usb3_imaging_stream_diag ch4_usb3_imaging_stream_diag.ltx]
set output_file [file join $root tmp usb3_imaging_stream_diag.csv]
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
if {$ila eq ""} { error "usb_stream_ila not found; verify matching BIT/LTX are loaded" }
set probe [lindex [get_hw_probes -of_objects $ila -filter {NAME =~ "*usb_stream_debug*"}] 0]
if {$probe eq ""} { error "usb_stream_debug probe not found" }

# Build a 32-bit don't-care pattern with only bit 6 constrained high.
set trigger_bits [string repeat X 32]
set trigger_bits [string replace $trigger_bits 25 25 1]
set_property TRIGGER_COMPARE_VALUE "eq32'b${trigger_bits}" $probe
set_property CONTROL.TRIGGER_CONDITION AND $ila
set_property CONTROL.TRIGGER_POSITION 1024 $ila
set_property CONTROL.DATA_DEPTH 4096 $ila

puts "USB3_IMAGING_ILA_ARMED: run Usb3LoopbackTest.exe 1 --stream now"
flush stdout
run_hw_ila $ila
wait_on_hw_ila $ila
puts "USB3_IMAGING_ILA_TRIGGERED status=[get_property STATUS.CORE_STATUS $ila] samples=[get_property STATUS.SAMPLE_COUNT $ila]"
upload_hw_ila_data $ila
write_hw_ila_data -force -csv_file $output_file [get_hw_ila_data -of_objects $ila]
puts "USB3_IMAGING_ILA_CSV=$output_file"
close_hw_manager
