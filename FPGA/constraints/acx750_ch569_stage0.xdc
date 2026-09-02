# ACX750-CH569 stage-0 reviewed pins from the project requirements.
create_clock -name sys_clk -period 20.000 [get_ports sys_clk]

set_property PACKAGE_PIN W19 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]

set_property PACKAGE_PIN D21 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS25 [get_ports sys_rst_n]

set_property PACKAGE_PIN L21 [get_ports uart_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rxd]

set_property PACKAGE_PIN M21 [get_ports uart_txd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_txd]

# Fast-mirror differential pins C18/C19 and E19/D19 are reserved for stage 1.
# They are deliberately not constrained until the external RS-422 transceiver,
# polarity, termination, and bank voltage have been checked on the real board.

