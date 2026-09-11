open_hw_manager
connect_hw_server
open_hw_target
set device [lindex [get_hw_devices xc7a200t_0] 0]
if {$device eq ""} {error "xc7a200t_0 was not found"}
current_hw_device $device
refresh_hw_device $device
set base [file normalize [file join [file dirname [info script]] .. build usb3_imaging_stream_diag]]
set_property PROGRAM.FILE [file join $base ch4_usb3_imaging_stream_diag.bit] $device
set_property PROBES.FILE [file join $base ch4_usb3_imaging_stream_diag.ltx] $device
set_property FULL_PROBES.FILE [file join $base ch4_usb3_imaging_stream_diag.ltx] $device
program_hw_devices $device
refresh_hw_device $device
puts "USB3_IMAGING_STREAM_DIAG_PROGRAM_PASS"
close_hw_manager
