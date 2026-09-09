# HRACT is the first CH569-to-FPGA HSPI request.  The factory FPGA design only
# asserts HTACK after both Rx_En and HRACT are present.
set root [file normalize [file join [file dirname [info script]] .. ..]]
set probes_file [file join $root FPGA build usb3_loopback vendor_top.ltx]
if {[info exists ::env(USB3_PROBES_FILE)] && $::env(USB3_PROBES_FILE) ne ""} {
    set probes_file [file normalize $::env(USB3_PROBES_FILE)]
}

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
set device [lindex [get_hw_devices -filter {PART =~ "xc7a200t*"}] 0]
if {$device eq ""} { error "xc7a200t device not found" }
current_hw_device $device
set_property PROBES.FILE $probes_file $device
refresh_hw_device $device

set ila [lindex [get_hw_ilas -of_objects $device -filter {CELL_NAME =~ "*HSPI_Rx*"}] 0]
if {$ila eq ""} { error "factory HSPI_Rx ILA not found" }
set hreact [lindex [get_hw_probes -of_objects $ila -filter {NAME =~ "*/HRACT"}] 0]
if {$hreact eq ""} { error "HRACT probe not found" }
set_property TRIGGER_COMPARE_VALUE "eq1'b1" $hreact
set_property CONTROL.TRIGGER_CONDITION AND $ila
set_property CONTROL.TRIGGER_POSITION 64 $ila
set_property CONTROL.DATA_DEPTH 8192 $ila

puts "USB3_HRACT_ILA_ARMED: run Usb3LoopbackTest.exe once now"
flush stdout
run_hw_ila $ila
wait_on_hw_ila $ila
puts "USB3_HRACT_ILA_STOPPED status=[get_property STATUS.CORE_STATUS $ila] samples=[get_property STATUS.SAMPLE_COUNT $ila]"
close_hw_manager
