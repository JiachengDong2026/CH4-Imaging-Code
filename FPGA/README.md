# FPGA 阶段 1

Artix-7 `xc7a200tfbg484-2`、50 MHz 工程。阶段 1 顶层已经接入 25.6 MSPS HITRAN ROM、真实 1f/2f 正交解调、特征提取、内部 Z 字演示轨迹、48 字节融合点和 UART 命令/数据发送。

快反镜原生 9 字节链路已接入顶层，使用 4.608 Mbps UART 和 `LVDS_25` 差分接口；当前引脚约束为：接收 `F19/F20`，发送 `F18/E18`。上板前仍需确认板卡 Bank 电压和外部收发器电气连接。

```powershell
.\scripts\build.ps1 -RunTests
```

该命令执行综合、统一应用协议仿真以及 HITRAN ROM → DILA → WMS 特征的端到端仿真，并输出综合检查点 `FPGA/build/syntax/stage1_synth.dcp`。

生成使用 HITRAN ROM、DILA 与内部扫描轨迹的成像比特流：

```powershell
.\scripts\build.ps1 -Bitstream
```

输出为 `FPGA/build/bitstream/ch4_imaging.bit`。该版本包含快反镜差分接口和反馈解析；未收到有效反馈前融合点使用内部轨迹，收到反馈后切换到快反镜实际角度。

当前 bitstream 为实验室调试版本：实现 DRC 无错误，但最终布局布线报告的 WNS 约为 `-65.147 ns`，不应作为时序收敛的正式版本使用。

严格构建脚本在 WNS 小于 0 时会主动失败；本次调试 bitstream 使用以下脚本生成：

```powershell
& 'D:\Software\Vivado\Vivado\2020.2\bin\vivado.bat' -mode batch -source scripts/build_bitstream_allow_negative_timing.tcl
```

固件在收到“开始扫描、开始采集、开始数据流”后，以 500 点/秒发送融合结果，并以旋转抽样方式发送 100 点 1f/2f 曲线。UART 带宽不足以逐点上传每个 2 kHz 光谱扫描周期，因此完整曲线每 100 ms 刷新一次；相邻波形点始终对应同一波长位置。

连接唯一一块 `xc7a200t` JTAG 设备后，可下载到 FPGA 的易失性配置存储器：

```powershell
.\scripts\program.ps1
```

断电后该配置会消失；本阶段不写板载配置 Flash。

脚本使用需求指定的 Vivado 2020.2，所有工程、日志和仿真结果写入 `FPGA/build` 或 `FPGA/vivado`。

创建可在 Vivado GUI 打开的工程：

```powershell
& 'D:\Software\Vivado\Vivado\2020.2\bin\vivado.bat' -mode batch -source scripts/create_project.tcl
```
