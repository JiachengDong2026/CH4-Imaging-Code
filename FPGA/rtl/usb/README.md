# USB / HSPI

阶段2的第一个独立目标是 `ch4_usb3_loopback_top`。它兼容开发板配套的
200T CH569 USB3.0 LoopBack固件，每次接收并原样返回一个4096字节块：

- CH569作为HSPI主机，FPGA接收时钟为外部`HRCLK`；
- FPGA使用MMCM从50 MHz生成120 MHz，再分频得到已经过硬件验收的30 MHz `HTCLK`；
- 32位共享数据总线通过IOBUF切换方向，仅在`HTREQ && !HRACT`时由FPGA驱动；
- 2048×32异步FIFO隔离两个HSPI时钟域；
- FPGA收发事务均为1个头字、1024个数据字和1个CRC尾字；TX必须等待完整RX事务结束；
- 此顶层与DILA、UART和快反镜完全隔离，只用于验证USB3.0物理链路。

运行RTL闭环仿真：

```powershell
& 'D:\Software\Vivado\Vivado\2020.2\bin\vivado.bat' -mode batch -source FPGA/scripts/run_usb3_loopback_test.tcl
```

生成严格时序检查的独立bitstream：

```powershell
& 'D:\Software\Vivado\Vivado\2020.2\bin\vivado.bat' -mode batch -source FPGA/scripts/build_usb3_loopback.tcl
```

统一应用协议将在下一检查点接到FIFO的系统时钟侧，帧格式不变。

`usb_hspi_block_packer.v` 是该检查点的第一层适配器。它接收现有
`app_frame_serializer` 的字节流，将一帧按小端顺序装入一个4096字节块，并以零
填充块尾。应用帧最大为4093字节，因此不会跨越HSPI块边界。该模块只定义系统侧
ready/valid接口，尚未替换或修改硬件黄金基线的HSPI RX/TX模块。

`usb_fused_point_block_source.v` 将现有48字节融合点载荷交给统一协议串行器，生成
`FUSED_POINT (0x62)` 帧，再通过上述封装器形成4096字节块。它带有独立的16位应用
帧序号；当前只完成RTL和协议级仿真，还需要新的CH569流式固件主动接收FPGA数据并
送入USB EP1，不能直接配合仅由EP2写入触发的回环固件上板。

硬件黄金基线由`FPGA/vendor/ch569_loopback_baseline`中的厂家RX/TX、CRC、
控制器和FIFO/时钟IP配置构建，顶层包含已经通过实物验收的30 MHz、
`HTREQ && !HRACT`总线方向保护及RX完成后再启动TX的修复。独立构建脚本
刻意不使用`FPGA/rtl/usb`中的通用重写模块；后者留给连续流阶段重构。

连接唯一一块200T板卡的JTAG后，可下载该临时镜像：

```powershell
& 'D:\Software\Vivado\Vivado\2020.2\bin\vivado.bat' -mode batch -source FPGA/scripts/program_usb3_loopback.tcl
```

也可以先使用厂商原始回环镜像进行基线验证。由于 Vivado 2020.2 的
Tcl 在中文路径下可能发生编码问题，先把配套资料中的 `top.bit` 复制到
`FPGA/build/usb3_loopback/vendor_top.bit`，再运行：

```powershell
& 'D:\Software\Vivado\Vivado\2020.2\bin\vivado.bat' -mode batch -source FPGA/scripts/program_vendor_usb3_loopback.tcl
```

注意：USB 接口由 CH569 MCU 实现，不是 FPGA 直接实现。CH569 回环固件在
调用 `USB30D_init(ENABLE)` 前会等待 PA12 为高；PA12 对应 FPGA 的
`Bitstream_Done`/C19。下载 FPGA 后必须短按一次 `USB_RST`，使 CH569 重新
执行启动流程。Windows 中出现 `WCH USB2.0 DEVICE` 且测试程序能打开设备，
表示枚举和驱动已经基本正常；此时若 EP1 回读为 0，应继续检查复位、固件、
C19 和 HSPI，而不是重复安装上位机端点测试程序。

当前 `ch2` 回环还需要三根控制跳线：FPGA C19 -> U29-5（PA12），FPGA
E19 -> U29-6（PA14），FPGA D19 -> U29-8（PA15）。教程中仅有的
`GPIO1 -> U29-8` 说明对应速度测试例程，不是本回环例程的完整接线。

`usb_fused_point_stream_bridge.v` 是真实融合结果接入USB路径的弹性边界。它使用
384位双时钟FIFO把50 MHz成像域跨到120 MHz USB打包域，向上下游提供
`valid/ready`接口，并分别统计接受、启动发送和因FIFO满而丢弃的帧数。黄金流式
测试顶层保持不变，后续系统顶层通过该模块连接成像流水线的
`emit_point/fused_payload`与`usb_fused_point_block_source`。

真实数据硬件验收顶层为`ch4_usb3_imaging_stream_top.v`。它复用HITRAN ROM、
25.6 MSPS采样调度、DILA、扫描成帧与WMS特征提取链路，每个真实融合结果通过
双时钟FIFO进入USB域；CH569每次拉高`Tx_Ctrl`时只发送一个4096字节块。构建与
下载脚本分别为`build_usb3_imaging_stream.tcl`和
`program_usb3_imaging_stream.tcl`，不会覆盖黄金流式测试bitstream。
