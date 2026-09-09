# Observe whether the factory firmware reaches the second HSPI phase.  It
# asserts PA15/Tx_En only after the first CH569-to-FPGA HSPI transfer completes.
set root [file normalize [file join [file dirname [info script]] .. ..]]
set probes_file [file join $root FPGA build usb3_loopback vendor_top.ltx]
set output_file [file join $root tmp vendor_usb3_tx_ila.csv]
if {[info exists ::env(USB3_PROBES_FILE)] && $::env(USB3_PROBES_FILE) ne ""} {
    set probes_file [file normalize $::env(USB3_PROBES_FILE)]
}
if {[info exists ::env(USB3_TX_CSV)] && $::env(USB3_TX_CSV) ne ""} {
    set output_file [file normalize $::env(USB3_TX_CSV)]
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

set ila [lindex [get_hw_ilas -of_objects $device -filter {CELL_NAME =~ "*HSPI_Tx*"}] 0]
if {$ila eq ""} { error "factory HSPI_Tx ILA not found" }
foreach probe [get_hw_probes -of_objects $ila] {
    set width [get_property WIDTH $probe]
    if {$width == 1} {
        set_property TRIGGER_COMPARE_VALUE "eq1'bX" $probe
    } elseif {$width == 32} {
        set_property TRIGGER_COMPARE_VALUE "eq32'hXXXX_XXXX" $probe
    }
}
set htreq [lindex [get_hw_probes -of_objects $ila -filter {NAME =~ "*/HTREQ"}] 0]
if {$htreq eq ""} { error "HTREQ probe not found" }
set_property TRIGGER_COMPARE_VALUE "eq1'b1" $htreq
set_property CONTROL.TRIGGER_CONDITION AND $ila
set_property CONTROL.TRIGGER_POSITION 64 $ila
set_property CONTROL.DATA_DEPTH 2048 $ila

puts "USB3_TX_ILA_ARMED: run Usb3LoopbackTest.exe once now"
flush stdout
run_hw_ila $ila
wait_on_hw_ila $ila
puts "USB3_TX_ILA_STOPPED status=[get_property STATUS.CORE_STATUS $ila] samples=[get_property STATUS.SAMPLE_COUNT $ila]"
upload_hw_ila_data $ila
write_hw_ila_data -force -csv_file $output_file [get_hw_ila_data -of_objects $ila]
puts "USB3_TX_ILA_CSV=$output_file"
close_hw_manager
