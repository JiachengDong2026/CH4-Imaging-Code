set root [file normalize [file join [file dirname [info script]] .. ..]]
set bitstream [file join $root FPGA build usb3_hspi_diagnostic ch4_usb3_hspi_diagnostic.bit]
if {![file exists $bitstream]} {error "diagnostic bitstream not found: $bitstream"}
open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
set device [lindex [get_hw_devices -filter {PART =~ "xc7a200t*"}] 0]
if {$device eq ""} {error "xc7a200t device not found"}
current_hw_device $device
set_property PROGRAM.FILE $bitstream $device
program_hw_devices $device
refresh_hw_device $device
puts "USB3_HSPI_DIAGNOSTIC_PROGRAM_PASS"
close_hw_manager
