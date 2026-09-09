# ACX750-CH569 USB3.0 最小回环测试

该程序使用系统当前安装的 WCH 32 位 `CH375DLL.dll`，打开设备 0，通过 EP2 OUT
发送数据，再通过 EP1 IN 读回并逐字节校验。程序会打印候选 DLL 和实际加载 DLL
的完整路径、版本、接口返回值、实际传输长度和耗时。

## 使用

1. Program the FPGA loopback image and the official CH569 loopback firmware.
2. Connect the three loopback control jumpers: FPGA C19 -> U29-5,
   FPGA E19 -> U29-6, and FPGA D19 -> U29-8.
3. Close `USB3.0Demo.exe`, Bus Hound, and other software that may own the device.
4. Short-press the board `USB_RST` button once. Do not press `BOOT`.
5. 先运行只写诊断：`bin/Usb3LoopbackTest.exe 1 --api standard --write-only`。
6. 短按一次 `USB_RST`，再运行完整回环：`bin/Usb3LoopbackTest.exe 1`。
7. 需要交叉验证端点接口时运行：`bin/Usb3LoopbackTest.exe 1 --api endpoint`。

默认使用官方标准批量接口 `CH375WriteData/CH375ReadData`。`--api endpoint` 改用
`CH375WriteEndP(EP2)/CH375ReadEndP(pipe1)`；`--size` 只接受 1024 或 4096；
`--write-only` 成功后 CH569 会进入下一阶段等待，所以再次测试前必须复位 CH569。

Interpret the result in this order:

- `无法打开设备 0`: USB enumeration or the CH375-compatible driver is not ready.
- `EP2 仅写入 0/4096`: stop at the USB/driver/CH569 endpoint layer; do not infer
  an FPGA or CRC failure.
- `EP1 仅读回 0/4096`: the device is enumerated, but CH569/HSPI/FPGA did not
  complete the loopback. Reset CH569, check C19, and verify the firmware.
- `USB3_LOOPBACK_PASS`: USB, CH569, HSPI, and FPGA loopback all passed.

出现 `USB3_LOOPBACK_PASS` 表示 USB、CH569、HSPI 和 FPGA 回环链路全部通过。

重新编译：在 PowerShell 中运行 `./build.ps1`。构建脚本从
`C:\Windows\SysWOW64\CH375DLL.DLL` 复制当前已安装的 x86 DLL，并打印版本和
SHA-256；不再复制配套资料中的旧版 2.9 DLL。
