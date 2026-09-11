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

# Fast-mirror device-side differential UART, matching uart_bridge_v4.
set_property PACKAGE_PIN F19 [get_ports mirror_rxd_p]
set_property PACKAGE_PIN F20 [get_ports mirror_rxd_n]
set_property IOSTANDARD LVDS_25 [get_ports {mirror_rxd_p mirror_rxd_n}]
set_property PACKAGE_PIN F18 [get_ports mirror_txd_p]
set_property PACKAGE_PIN E18 [get_ports mirror_txd_n]
set_property IOSTANDARD LVDS_25 [get_ports {mirror_txd_p mirror_txd_n}]
