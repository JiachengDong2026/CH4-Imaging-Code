# Attach the factory probes file to the already-programmed 200T USB3 loopback
# design, then list the ILA cores/probes.  This script never programs flash or
# changes the FPGA configuration.
set root [file normalize [file join [file dirname [info script]] .. ..]]
set probes_file [file join $root FPGA build usb3_loopback vendor_top.ltx]
if {[info exists ::env(USB3_PROBES_FILE)] && $::env(USB3_PROBES_FILE) ne ""} {
    set probes_file [file normalize $::env(USB3_PROBES_FILE)]
}
if {![file exists $probes_file]} { error "factory probes file not found: $probes_file" }

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
set devices [get_hw_devices -filter {PART =~ "xc7a200t*"}]
if {[llength $devices] != 1} { error "expected exactly one xc7a200t device, found [llength $devices]" }
set device [lindex $devices 0]
current_hw_device $device
set_property PROBES.FILE $probes_file $device
refresh_hw_device $device

set ilas [get_hw_ilas -of_objects $device]
puts "VENDOR_USB3_ILA_COUNT=[llength $ilas]"
foreach ila $ilas {
    puts "ILA=$ila NAME=[get_property NAME $ila] CELL=[get_property CELL_NAME $ila]"
    report_property $ila
    foreach probe [get_hw_probes -of_objects $ila] {
        puts "  PROBE=[get_property NAME $probe] WIDTH=[get_property WIDTH $probe]"
        report_property $probe
    }
}
close_hw_manager
