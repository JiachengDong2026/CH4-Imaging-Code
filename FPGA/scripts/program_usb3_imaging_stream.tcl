open_hw_manager
connect_hw_server
open_hw_target
set device [lindex [get_hw_devices xc7a200t_0] 0]
if {$device eq ""} {error "xc7a200t_0 was not found"}
current_hw_device $device
refresh_hw_device $device
set bitfile [file normalize [file join [file dirname [info script]] .. build usb3_imaging_stream ch4_usb3_imaging_stream.bit]]
set_property PROGRAM.FILE $bitfile $device
program_hw_devices $device
refresh_hw_device $device
puts "USB3_IMAGING_STREAM_PROGRAM_PASS $bitfile"
close_hw_manager
