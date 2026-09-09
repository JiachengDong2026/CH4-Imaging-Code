set root [file normalize [file join [file dirname [info script]] .. ..]]
set vendor_bitstream [file join $root FPGA build usb3_loopback vendor_top.bit]
if {![file exists $vendor_bitstream]} {error "vendor bitstream not found: $vendor_bitstream"}
open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
set devices [get_hw_devices -filter {PART =~ "xc7a200t*"}]
if {[llength $devices] != 1} {error "expected exactly one xc7a200t device, found [llength $devices]"}
set device [lindex $devices 0]
current_hw_device $device
refresh_hw_device $device
set_property PROGRAM.FILE $vendor_bitstream $device
program_hw_devices $device
refresh_hw_device $device
puts "VENDOR_USB3_LOOPBACK_PROGRAM_PASS device=$device bitstream=$vendor_bitstream"
close_hw_manager
