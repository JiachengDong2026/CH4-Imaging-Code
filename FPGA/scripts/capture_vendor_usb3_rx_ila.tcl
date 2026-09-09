# Capture the factory USB3-loopback receiver ILA once after CH569 asserts
# Rx_En.  Start this script first, then run Usb3LoopbackTest.exe once.
set root [file normalize [file join [file dirname [info script]] .. ..]]
set probes_file [file join $root FPGA build usb3_loopback vendor_top.ltx]
set output_file [file join $root tmp vendor_usb3_rx_ila.csv]
if {[info exists ::env(USB3_PROBES_FILE)] && $::env(USB3_PROBES_FILE) ne ""} {
    set probes_file [file normalize $::env(USB3_PROBES_FILE)]
}
if {[info exists ::env(USB3_RX_CSV)] && $::env(USB3_RX_CSV) ne ""} {
    set output_file [file normalize $::env(USB3_RX_CSV)]
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

set ila [lindex [get_hw_ilas -of_objects $device -filter {CELL_NAME =~ "*HSPI_Rx*"}] 0]
if {$ila eq ""} { error "factory HSPI_Rx ILA not found" }
set fifo_wr_en [lindex [get_hw_probes -of_objects $ila -filter {NAME =~ "*/FIFO_WR_EN"}] 0]
if {$fifo_wr_en eq ""} { error "FIFO_WR_EN probe not found" }
set_property TRIGGER_COMPARE_VALUE "eq1'b1" $fifo_wr_en
set_property CONTROL.TRIGGER_CONDITION AND $ila
set_property CONTROL.TRIGGER_POSITION 0 $ila
set_property CONTROL.DATA_DEPTH 1024 $ila

puts "USB3_RX_ILA_ARMED: run Usb3LoopbackTest.exe once now"
flush stdout
run_hw_ila $ila
wait_on_hw_ila $ila
puts "USB3_RX_ILA_CAPTURED samples=[get_property STATUS.SAMPLE_COUNT $ila]"
upload_hw_ila_data $ila
write_hw_ila_data -force -csv_file $output_file [get_hw_ila_data -of_objects $ila]
puts "USB3_RX_ILA_CSV=$output_file"
close_hw_manager
