# Read-only report: map the factory USB3 loopback pins to FPGA I/O banks.
open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
set device [lindex [get_hw_devices -filter {PART =~ "xc7a200t*"}] 0]
if {$device eq ""} { error "xc7a200t device not found" }
set part xc7a200tfbg484-2
puts "USB3_FPGA_PART=$part"
set_property DESIGN_MODE PinPlanning [current_fileset]
open_io_design -part $part
foreach pin {C19 E19 D19 AA20 W11 AA21 U17 V13 U16 V17 U18} {
    set obj [get_package_pins $pin]
    puts "PIN=$pin BANK=[get_property BANK $obj]"
}
close_design
close_hw_manager
