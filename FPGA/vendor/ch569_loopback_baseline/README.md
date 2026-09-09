# CH569 HSPI hardware baseline

This directory contains the source and IP configurations used to rebuild the
hardware-qualified 4096-byte USB3/HSPI loopback baseline.

The RTL originated from the ACX750-CH569 200T vendor loopback example.  The
qualified wrapper adds three changes proven on the physical board:

- transmit HSPI at 30 MHz;
- drive the shared `HD[31:0]` bus only while `HTREQ && !HRACT`;
- wait for the complete receive transaction before starting transmit.

`HSPI_Rx.v` and `HSPI_Tx.v` keep their ILA instances behind
`HSPI_DEBUG_ILA`; the release build does not define that macro.  Build and
program with:

```powershell
& 'D:\Software\Vivado\Vivado\2020.2\bin\vivado.bat' -mode batch -source FPGA/scripts/build_usb3_loopback.tcl
& 'D:\Software\Vivado\Vivado\2020.2\bin\vivado.bat' -mode batch -source FPGA/scripts/program_usb3_loopback.tcl
```

The validated output is `FPGA/build/usb3_loopback/ch4_usb3_loopback.bit`.
Its 2026-09-09 hardware-acceptance SHA-256 is
`71E55D40D9583C59521BCD2F3432E638592619194A55354DF9AF252FD0316064`.
