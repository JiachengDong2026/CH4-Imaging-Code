set root [file normalize [file join [file dirname [info script]] .. ..]]
set bitfile [file join $root FPGA build usb3_stream_test ch4_usb3_stream_test.bit]
if {![file exists $bitfile]} {error "Bitstream not found: $bitfile"}

open_hw_manager
connect_hw_server
open_hw_target
set devices [get_hw_devices xc7a200t_0]
if {[llength $devices] != 1} {error "Expected exactly one xc7a200t_0, found [llength $devices]"}
set device [lindex $devices 0]
current_hw_device $device
refresh_hw_device $device
set_property PROGRAM.FILE $bitfile $device
program_hw_devices $device
refresh_hw_device $device
puts "USB3_STREAM_TEST_PROGRAM_PASS $bitfile"
close_hw_manager
