# ACX750-CH569 USB3.0 接口回环调试记录

> 最后更新：2026-09-09  
> 当前状态：**USB3.0/CH569/HSPI/FPGA 4096 字节端到端回环已通过；主项目已纳入可重建的30 MHz无ILA黄金基线，下一步进入阶段2连续主数据通道开发。**  
> 后续上位机测试工具：`E:\Documents\CH4_Imaging_Code_v2\Tools\Usb3LoopbackTest`  
> 后续不再以厂家 `USB3.0Demo.exe` 作为主要测试工具。

## 1. 文档目的

本文记录 ACX750-CH569（Artix-7 200T）开发板 USB3.0 回环测试的目标、硬件链路、已经完成的工作、实测结果、已经调通的部分、当前故障、原因分析和后续调试步骤。

本文只描述 USB/CH569/HSPI/FPGA 回环链路。阶段 2 中 DILA 参数可调、仿真气体吸收数据上传和正式应用协议的接入，需要在本回环链路稳定通过后继续完成。

## 2. 阶段 2 与当前回环任务目标

阶段 2 的总体目标包括：

1. 使用 USB3.0 作为 FPGA 与 PC 之间的高速主数据通道；
2. 在真实 ADC 到货前，继续使用 FPGA 内部的仿真甲烷吸收数据；
3. 实现 DILA 参数可调，并通过上位机配置；
4. 最终通过 USB3.0 上传原始/处理中间数据、1f、2f、归一化 2f 和融合数据。

当前独立检查点不是直接接入 DILA，而是先跑通厂家定义的最小 4096 字节回环：

```text
PC 生成 4096 字节测试数据
  -> USB Bulk OUT EP 0x02
  -> CH569 的 EP2 接收缓冲区
  -> CH569 作为 HSPI 主机发送给 FPGA
  -> FPGA 写入异步 FIFO
  -> FPGA 从 FIFO 原样取出并通过 HSPI 返回 CH569
  -> CH569 对 HSPI 包序号和 CRC 进行硬件检查
  -> USB Bulk IN EP 0x81
  -> PC 读回 4096 字节并逐字节比较
```

只有出现 `USB3_LOOPBACK_PASS`，才能认为 USB、CH569、两方向 HSPI、FPGA FIFO、HSPI 包序号、CRC 和 USB 回传全部通过。

## 3. 硬件与协议链路

### 3.1 USB 接口归属

开发板 USB3.0 接口由 CH569 芯片直接连接电脑，不是 FPGA 直接实现 USB 协议：

```text
PC <-> USB3.0 <-> CH569 <-> 32 位 HSPI <-> FPGA
```

因此：

- 仅下载 FPGA bitstream 不能让电脑枚举 USB 设备；
- CH569 必须烧录正确的 USB/HSPI 固件；
- CH569 固件、USB 驱动、USB 线缆、USB 主机端口、HSPI 板内连接和 FPGA bitstream 均会影响结果；
- Windows 能枚举设备，只能证明控制端点和部分 USB 链路工作，不能证明 EP2、HSPI 和 EP1 回环已经通过。

### 3.2 HSPI 信号方向

以下命名以 FPGA 侧为观察对象：

| 方向 | 主要信号 | 作用 |
|---|---|---|
| CH569 -> FPGA | `HRCLK`、`HRACT`、`HRVLD`、`HD[31:0]` | CH569 向 FPGA 发送包头、4096 字节载荷和 CRC |
| FPGA -> CH569 | `HTCLK`、`HTREQ`、`HTVLD`、`HD[31:0]` | FPGA 向 CH569 回传包头、载荷和 CRC |
| 握手 | `HTACK`、`HTRDY` | 两个方向的数据准备/接受握手 |
| 方向控制 | `Rx_Ctrl`、`Tx_Ctrl` | CH569 固件通知 FPGA 当前进行接收或发送阶段 |

`HRACT` 是 CH569 到 FPGA 的 HSPI 接收活动信号，对应 FPGA 封装引脚 `AA20`。它不是三根外接跳线中的一根。

### 3.3 三根控制跳线

厂家 200T `ch2` 回环例程需要以下三根线：

| FPGA 引脚 | FPGA 信号 | U29 引脚 | CH569 信号 | 作用 |
|---|---|---:|---|---|
| `C19` | `Bitstream_Done` | 5 | PA12 / `SCS1#` | FPGA 配置完成指示；CH569 启动时等待它为高 |
| `E19` | `Rx_Ctrl` | 6 | PA14 / `MOSI1` | 允许 FPGA 接收 CH569 发来的 HSPI 数据 |
| `D19` | `Tx_Ctrl` | 8 | PA15 / `MISO1` | 允许 FPGA 向 CH569 回传 HSPI 数据 |

三根跳线是回环状态控制信号，与 HSPI 事务有关，但不是完整的 32 位 HSPI 数据总线。`HD[31:0]`、时钟及其他握手信号通过核心板与底板之间的板内连接器连接。

教程中某些速度测试只使用一根 `GPIO1 -> U29-8` 跳线，不能替代本回环例程所需的三根控制线。

### 3.4 FPGA I/O 电平注意事项

当前回环 XDC 将 HSPI 数据和控制信号设置为 `LVCMOS33`。此前硬件 GPIO 电压选择曾设置为 2.5 V，但尚未确认该选择器是否直接控制 HSPI 所在 FPGA Bank 的 VCCO，亦未完成 CH569 I/O 电平与 FPGA Bank 电压的原理图级复核。

后续必须确认：

1. HSPI 所在 FPGA Bank 的实际 VCCO；
2. CH569 HSPI I/O 电压；
3. 板上可选 1.5/1.8/2.5/3.3 V 跳帽实际控制的电源域；
4. XDC `IOSTANDARD` 与真实 VCCO 是否一致。

在上述信息确认前，不应仅凭“2.5 V 或 3.3 V 中哪个能工作”反复试错。

## 4. 使用的工程、固件和工具

### 4.1 厂家资料

- 教程：`E:\Work\甲烷巡检系统\盘A_ACX750-CH569 USB3.0开发板标准配套资料\01_教材文档\04_【教材文档】ACX750-CH569 USB3.0教程文档v1.2.pdf`
- 厂家 200T 回环例程：`E:\Work\甲烷巡检系统\盘A_ACX750-CH569 USB3.0开发板标准配套资料\02 设计实例\USB3.0例程\200t\ch2_ACX750_CH569_200T_USB30_LoopBack`

### 4.2 专项调试副本

已复制厂家回环工程到：

```text
E:\Documents\Vivado\ch2_ACX750_CH569_200T_USB30_LoopBack
```

该目录包含 FPGA 工程、CH569 固件源码、诊断 bitstream、LTX、ILA Tcl 和 CSV。后续分析历史波形时应以该目录为准。

最近使用的诊断镜像：

```text
USB30_LoopBack\bit\top_hspi_tx_30m_diag.bit
USB30_LoopBack\bit\top_hspi_tx_30m_diag.ltx
```

注意：bitstream 与 LTX 必须成对使用。切换 bitstream 后不能继续使用旧 LTX 解释 ILA。

### 4.3 主项目中的 USB/HSPI 代码

主项目已经准备独立 USB 回环顶层和构建脚本：

- `FPGA/rtl/top/ch4_usb3_loopback_top.v`
- `FPGA/rtl/usb/hspi_loopback_rx.v`
- `FPGA/rtl/usb/hspi_loopback_tx.v`
- `FPGA/rtl/usb/hspi_async_fifo.v`
- `FPGA/rtl/usb/hspi_crc32_32.v`
- `FPGA/constraints/acx750_ch569_usb3_loopback.xdc`
- `FPGA/sim/tb_usb3_loopback.v`
- `FPGA/scripts/run_usb3_loopback_test.tcl`
- `FPGA/scripts/build_usb3_loopback.tcl`
- `FPGA/scripts/program_usb3_loopback.tcl`
- `FPGA/scripts/capture_vendor_usb3_rx_ila.tcl`
- `FPGA/scripts/capture_vendor_usb3_tx_trigger.tcl`

该顶层只用于 4096 字节回环，不包含 DILA、快反镜或正式应用协议。

### 4.4 CH569 固件

主项目保存的厂家原始 HEX：

```text
Firmware\CH569\HSPI_USB_Loopback.hex
SHA-256 = 2C4E2F9BD65A1FDD94D3CC04A87FA8480275D402E7D3BCA1EB6C354A4C2DAFF0
```

已确认该文件与厂家资料中的原始 HEX 哈希一致。

CH569 源码关键文件：

```text
E:\Documents\Vivado\ch2_ACX750_CH569_200T_USB30_LoopBack\HSPI_USB_Loopback\User\Main.c
E:\Documents\Vivado\ch2_ACX750_CH569_200T_USB30_LoopBack\HSPI_USB_Loopback\USB30\CH56x_usb30.c
E:\Documents\Vivado\ch2_ACX750_CH569_200T_USB30_LoopBack\HSPI_USB_Loopback\USB20\CH56x_usb20.c
E:\Documents\Vivado\ch2_ACX750_CH569_200T_USB30_LoopBack\HSPI_USB_Loopback\SRC\Peripheral\inc\CH56xSFR.h
```

### 4.5 当前上位机测试工具

后续统一使用：

```text
E:\Documents\CH4_Imaging_Code_v2\Tools\Usb3LoopbackTest\bin\Usb3LoopbackTest.exe
```

测试行为：

1. 打开设备索引 0；
2. 向 EP `0x02` 写入 4096 字节；
3. 从管道 1（对应 EP `0x81`）读取 4096 字节；
4. 逐字节比较发送和接收数据；
5. 成功时输出 `USB3_LOOPBACK_PASS`。

当前工具目录自带 `CH375DLL.dll 2.9`，而系统安装的 WCH 驱动和 `C:\Windows\SysWOW64\CH375DLL.DLL` 为 3.5。版本不一致是当前必须排除的上位机侧风险。

## 5. 已完成的工作与测试

### 5.1 硬件连接与替换

- 核对并连接了 `C19 -> U29-5`、`E19 -> U29-6`、`D19 -> U29-8` 三根回环控制跳线；
- 尝试过不同 USB 线缆；
- 更换过 FPGA 核心板后继续测试；
- 多次烧录 FPGA bitstream；
- 多次烧录 CH569 HEX，并在烧录后复位 CH569；
- 已安装 MounRiver Studio，可继续编译和修改 CH569 固件；
- 已安装 WCH 驱动/烧录工具。

以上操作只能说明连接和编程流程已经实际执行，不能单独证明每次烧录内容、复位顺序和运行时状态完全一致。后续应在每轮测试记录中固定 bit/ltx/hex 哈希和烧录顺序。

### 5.2 Windows 枚举与驱动

历史上 Windows 已成功识别：

```text
Bus reported name: WCH USB3.0 DEVICE
VID_1A86&PID_5537
PnP status: OK
Driver service: CH375_A64
Driver version: 3.5.2025.8
```

这证明 CH569 曾完成 USB 枚举，芯片并非始终完全无响应。

最近一次测试后，该设备实例曾显示为：

```text
Present=False
Status=Unknown
Problem=CM_PROB_PHANTOM
```

随后上位机工具无法再次打开设备。现已确认这不是异常掉线：检查时电路板电源已经由用户关闭，`Present=False`、`CM_PROB_PHANTOM` 和“无法打开设备 0”均是断电后的正常结果，不应作为 USB 链路不稳定、CH569 异常复位或芯片损坏的证据。电路板上电时设备可以连接。

“设备名称包含 USB3.0”不等于已经确认实际协商速率为 SuperSpeed。后续仍应使用 UsbTreeView 检查 `Connection Information`/`Device Bus Speed`，并保存结果。

### 5.3 厂家 Demo 测试

厂家 `USB3.0Demo.exe` 曾显示：

```text
CH372/CH375 Bulk Data Loopback Program V1.0
*** CH375OpenDevice: 0#
```

这说明 DLL 能定位设备索引 0，但程序随后没有输出成功、失败或速率信息，表现为阻塞在第一次传输附近。由于其可观测性较差，后续不再将厂家 Demo 作为主要测试工具。

### 5.4 自建上位机工具测试

最新一次运行 `Usb3LoopbackTest.exe 1`：

```text
ACX750-CH569 USB3.0 最小回环测试
设备 0，USB EP 0x02 OUT -> FPGA -> USB EP 0x81 IN，每次 4096 字节
设备打开成功，句柄=0x370
第 1 次失败：EP2 仅写入 0/4096 字节。
```

关闭电路板电源后再次运行：

```text
失败：无法打开设备 0。
```

该结果只说明断电设备无法打开，不属于接口故障。当前有效的失败证据仍是电路板上电、设备成功打开时，EP2 实际写入 `0/4096`。

此前临时探测程序也得到过：

```text
CH375WriteData: ok=True, length=0
CH375WriteEndP(EP2): ok=True, length=0
```

因此“函数布尔返回成功”不能被当作传输成功，必须检查返回的实际长度是否为 4096。

历史上还曾出现以下结果：

- EP2 下传调用完成，但 EP1 读回 `0/4096`；
- 某次 EP1 读回 `4096/4096`，但数据偏移错误，后半段出现重复的 `C?AAAAAA` 类 HSPI 帧头数据。

这些历史结果说明链路曾推进到更后级，但测试时使用的 bitstream、固件状态、复位顺序和上位机版本没有形成完整的可复现实验记录，因此不能视为回环通过。

### 5.5 FPGA 编译、仿真和 ILA

已完成：

- 重新编译厂家回环 FPGA 工程并生成 bitstream；
- 增加 FPGA 自身时钟驱动的诊断 ILA，用于区分“ILA 时钟未运行”和“HSPI 没有触发”；
- 构建降低发送时钟的 30 MHz 诊断版本；
- 多次烧录 bitstream 并通过 Vivado Hardware Manager 连接 `xc7a200t`；
- 当前设计可识别 3 个 ILA 核；
- 编写 Tcl 脚本自动布防并导出 CSV。

主要历史 CSV：

```text
USB30_LoopBack\bit\hspi_rx_30m_wave.csv
USB30_LoopBack\bit\hspi_tx_30m_wave.csv
USB30_LoopBack\bit\hspi_tx_30m_diag_snapshot.csv
USB30_LoopBack\bit\hspi_diag_sticky_snapshot.csv
```

## 6. 已经调通或得到明确证据的部分

### 6.1 FPGA 配置与 ILA 基础设施

**已确认：**

- JTAG 能找到并连接 `xc7a200t`；
- FPGA bitstream 可以下载；
- Vivado 能识别 ILA 核；
- FPGA 自身时钟诊断 ILA 能工作；
- 能通过 batch Tcl 布防、等待触发、上传并导出 CSV。

因此“ILA 完全不触发”不能简单归因于 Vivado/JTAG/ILA 本身失效。

### 6.2 USB 枚举曾经成功

**已确认：** CH569 曾以 `VID_1A86&PID_5537` 枚举，Windows 驱动状态曾为 OK，上位机 DLL 曾返回有效设备句柄。

因此 CH569 芯片并非可以直接判定为损坏。芯片、供电、固件、复位或 USB 物理链路仍可能存在间歇性问题，但至少曾经执行到 USB 枚举阶段。

### 6.3 CH569 -> FPGA 的 HSPI 接收方向曾经工作

`hspi_rx_30m_wave.csv` 中观察到：

- `HRACT`、`HRVLD`、`HTACK` 均有有效变化；
- `FIFO_WR_EN` 有效 1024 个采样；
- `FIFO_FULL` 始终为 0；
- `Rx_Done` 出现一个完成脉冲；
- FIFO 开头数据依次为 `03020100`、`07060504`、`0B0A0908`、`0F0E0D0C`，与测试数据前几个 32 位字一致。

这证明在某次历史测试中，CH569 确实通过 HSPI 向 FPGA 发起过事务，FPGA 接收状态机、部分 32 位数据总线和 FIFO 写入路径确实工作过。

但该捕获中第一个可比对错误出现在第 22 个 32 位字，即字节偏移 `0x58`：

```text
期望：0x5B5A5958
实际：0xD497F855
```

后续出现大量 `CAAAAAAA`，因此只能认定“接收方向曾启动并完成状态计数”，不能认定“4096 字节数据完整可靠”。

### 6.4 FPGA -> CH569 的 HSPI 发送握手曾经发生

诊断 sticky ILA 曾同时记录：

```text
tx_ctrl_seen = 1
htreq_seen   = 1
htvld_seen   = 1
htrdy_seen   = 1
```

这说明 CH569 曾拉起 FPGA 回传控制，FPGA 曾产生 `HTREQ/HTVLD`，CH569 也曾产生 `HTRDY`。因此核心板与底板之间的 HSPI 发送方向不是永久开路。

但是 sticky 位只证明“自上次复位以来至少发生过一次”，不能证明四个信号属于同一笔完整且正确的回传事务。

### 6.5 当前 TX 捕获没有形成有效回传

`hspi_tx_30m_wave.csv` 中：

- `Tx_En` 有过 0/1 变化；
- `FIFO_EMPTY` 始终为 1；
- `HTREQ`、`HTVLD`、`HTRDY`、`FIFO_RD_EN`、`Tx_Done` 始终为 0。

因此该次捕获中虽然进入过 TX 控制阶段，但 FIFO 中没有可发送数据，未形成有效 FPGA -> CH569 事务。

## 7. CH569 固件代码分析

### 7.1 启动顺序

CH569 固件启动时等待 PA12，即 FPGA `Bitstream_Done/C19`：

```c
while(!GPIOA_ReadPortPin(GPIO_Pin_12));
HSPI_Init();
USB30D_init(ENABLE);
```

因此推荐顺序必须是：

1. 下载 FPGA bitstream；
2. 确认 `Bitstream_Done` 已为高；
3. 烧录或确认 CH569 固件；
4. 短按 `USB_RST` 或重新上电，让 CH569 从启动入口重新执行；
5. 等待 Windows 完成枚举；
6. 再运行上位机测试。

如果只重新下载 FPGA 而不复位 CH569，CH569 可能仍停留在上一轮异常状态。

### 7.2 主循环是串行阻塞状态机

厂家固件按以下顺序工作：

```text
等待 EP2 收满 4096 字节
  -> CH569 通过 HSPI 发送给 FPGA
  -> 等待 HSPI 发送完成
  -> 允许 FPGA 回传
  -> 等待 HSPI 接收完成且 CRC/序号正确
  -> 开启 EP1 IN 上传 4096 字节
  -> 等待主机读取完成
```

关键等待均为无超时死循环：

```c
while(ENDP2_Rx_Full_Flag == 0);
while(Tx_End_Flag == 0);
while(Rx_End_Flag == 0);
while(ENDP1_Tx_Full_Flag == 0);
```

任一阶段失败都会让固件永久停住，并使后续端点维持 NAK/未就绪状态。再次运行 PC 程序通常无法自动恢复，必须复位 CH569。

### 7.3 USB3.0 EP2 接收逻辑

主循环为 EP2 设置：

```c
USB30_OUT_Set(ENDP_2, ACK, DEF_ENDP2_OUT_BURST_LEVEL);
USB30_Send_ERDY(ENDP_2 | OUT, DEF_ENDP2_OUT_BURST_LEVEL);
```

配置为 1024 字节最大包、4 包 Burst，对应一次 4096 字节接收。EP2 回调在 `nump == 0` 时才设置：

```c
ENDP2_Rx_Full_Flag = 1;
```

当前上位机写入实际长度为 0，说明在设备上电且成功打开的该次测试中，主机没有完成任何 EP2 数据传输。优先怀疑 EP2 没有处于 ACK/ERDY、CH569 固件停在错误阶段、USB3 端点状态异常，或上位机 DLL/驱动组合不正确。随后观察到的设备不在线是人为关闭电路板电源所致，与这次 EP2 写入 0 是两个不同事件。

### 7.4 USB2.0 回退路径存在缺陷

USB2.0 的 EP2 OUT 中断当前只重新设置 DMA 地址、翻转 DATA toggle 并保持 ACK，没有：

- 累计已接收字节数；
- 在累计 4096 字节后设置 `ENDP2_Rx_Full_Flag`；
- 防止每个包都把 DMA 地址重置到缓冲区起点。

如果链路降级到 USB2.0，主循环会一直等待 `ENDP2_Rx_Full_Flag`，并且数据可能反复覆盖缓冲区开头。后续必须选择以下方案之一：

1. 明确要求并验证 SuperSpeed，USB2.0 模式直接给出错误并停止；
2. 正确实现 USB2.0 EP2 的 4096 字节分包累计接收。

### 7.5 HSPI CRC 和序号检查

CH569 使用 HSPI 硬件校验，不是在 C 代码中逐字节计算 CRC。接收完成中断读取 `R8_HSPI_RTX_STATUS`：

| 状态位 | 值 | 含义 |
|---|---:|---|
| `RB_HSPI_CRC_ERR` | `0x02` | CRC 错误 |
| `RB_HSPI_NUM_MIS` | `0x04` | 包序号不匹配 |
| 两位同时置位 | `0x06` | CRC 和序号均错误 |

只有两位都为 0，固件才设置 `Rx_End_Flag = 1`。出现任一错误时，主循环会永久卡在 `while(Rx_End_Flag == 0)`，EP1 不会上传数据。

当前正常固件没有以易观察的方式持续输出原始 `R8_HSPI_RTX_STATUS`，因此后续应增加一次性诊断记录。

## 8. FPGA 代码分析

### 8.1 当前发送帧格式

FPGA HSPI TX 状态机发送：

```text
1 个 32 位帧头
1024 个 32 位数据字（4096 字节）
1 个 32 位 CRC
```

发送帧头由长度低位、4 位包序号和 26 位用户字段组成。厂家 FPGA 代码的用户字段为交替比特模式，在线上表现为 `C?AAAAAA` 类数据。

### 8.2 当前 CRC 输入与线上帧头不一致

专项工程当前版本对 CRC 输入做过修改：

```verilog
assign wire_crc_data =
    ((SM_State == S_HEAD) ||
     ((SM_State == S_DATA) && (Cnt == 32'd0))) ?
    {Tx_Length_Low, Tx_Num_Sequence, 26'b0} : Tx_Data;
```

但实际发送的帧头仍是：

```verilog
Tx_Data <= {Tx_Length_Low, Tx_Num_Sequence, User_Define_Data};
```

即线上发送非零 `User_Define_Data`，CRC 却按 0 计算。这是明确的协议不一致，极可能导致 CH569 报 `RB_HSPI_CRC_ERR`。

解决时必须二选一并保持两端一致：

1. CRC 对实际线上发送的完整 `Tx_Data` 计算；推荐先恢复厂家行为；
2. 将实际帧头用户字段也改为 0，并确认 CH569 对帧头的解析允许该值。

在没有抓到 CH569 原始状态寄存器和完整 TX 波形前，不应仅凭 EP1 无数据就断言一定是 CRC 错。

### 8.3 可能的数据错位/计数问题

历史上曾出现 4096 字节回读但首部偏移、尾部重复帧头。结合 RX ILA 在字节偏移 `0x58` 开始错误，后续需检查：

- `HRVLD/HRACT` 与 `HD[31:0]` 的采样边沿；
- 首个数据字相对帧头的状态机延迟；
- FIFO 写使能与 `FIFO_DIN` 的一拍对齐；
- FIFO 读使能提前量；
- 1024 个 payload 字的计数终点；
- CRC 尾字是否被误写入 FIFO；
- 下一包帧头是否被误当作上一包 payload；
- 120 MHz 与 30 MHz 版本的时序裕量和跨时钟域复位。

## 9. 当前问题的分层结论

### 9.1 当前最前级故障：USB EP2 OUT 未成功

**状态：已确认。**

最新测试中：

- 设备一度可以打开；
- `CH375WriteEndP` 实际写入长度为 `0/4096`；
- 本次没有新的 `Rx_En/HRACT` HSPI 事务。

因此本轮失败发生在 `PC -> USB 驱动/DLL -> CH569 EP2`，早于 HSPI 和 FPGA CRC。

后续 Windows 当前设备列表中找不到设备以及第二次运行无法打开，是因为电路板电源已关闭，不是本轮传输导致的掉线，不能用于判断枚举稳定性。

### 9.2 后级故障：HSPI 数据完整性和 CRC 尚未通过

**状态：历史上已触发，但未完整通过。**

- CH569 -> FPGA 方向曾写入 1024 个 FIFO 字并出现 `Rx_Done`；
- 数据前若干字正确，但从偏移 `0x58` 起出现错误；
- FPGA -> CH569 方向曾出现完整握手 sticky 标志；
- 当前 TX 捕获则出现 FIFO 空、没有实际发送；
- FPGA 线上帧头与 CRC 输入存在明确不一致。

因此修复 EP2 后，仍需要继续修复 HSPI 数据对齐和 CRC。

## 10. 可能原因及优先级

| 优先级 | 可能原因 | 依据 | 验证方法 |
|---|---|---|---|
| P0 | CH569 固件卡在无超时等待状态 | 固件有四个永久 `while`；异常后不会自恢复 | 增加阶段码、超时和寄存器日志 |
| P0 | EP2 未 ACK、未发 ERDY或端点状态未正确恢复 | EP2 写入 0；无新 HSPI 触发 | 记录 EP2 回调、`nump/rx_len/status` 和 link 状态 |
| P1 | 上位机 DLL 2.9 与驱动 3.5 不匹配 | 应用优先加载旧 DLL，系统已安装 3.5 | 使用配套 3.5 x86 DLL重测，并记录 DLL版本 |
| P1 | 实际降级为 USB2.0，而 USB2 固件路径不完整 | USB2 EP2 不累计 4096 字节且不置完成标志 | UsbTreeView 确认速度；修复或禁用 USB2 回退 |
| P1 | 复位/烧录顺序不固定 | CH569 启动依赖 C19；下载 FPGA 后 CH569 可能仍在旧状态 | 固定“FPGA -> HEX -> USB_RST -> 枚举 -> 测试”顺序 |
| P1 | USB 线、主机口或 Hub 未建立预期的 SuperSpeed 链路 | 已更换线缆但尚未保存实际协商速度证据 | 直连主机 USB3 口、使用已知合格线，并用 UsbTreeView 确认速度 |
| P1 | 核心板与底板 HSPI 接触或电平不匹配 | 历史信号有时存在、有时不触发；曾更换核心板 | 复核连接器、VCCO、示波器测试点和 ILA sticky |
| P2 | HSPI 接收边沿/时序裕量不足 | 前若干字正确，偏移 `0x58` 后损坏 | 降频、切换采样边沿、检查时序约束和输入延迟 |
| P2 | FIFO/状态机存在一拍错位或计数边界错误 | 历史回读偏移、尾部出现帧头样式数据 | 对照 1024 字逐项检查写使能、读使能和计数器 |
| P2 | FPGA TX 的帧头和 CRC 覆盖内容不一致 | 当前源码明确存在不一致 | 统一 CRC 输入后读取 CH569 状态位 |
| P2 | HSPI 包序号不同步 | CH569 硬件会置 `0x04`，错误时不上传 EP1 | 输出 `R8_HSPI_RTX_STATUS` 原始值 |
| P3 | CH569 芯片本体损坏 | 不能完全排除，但曾成功枚举和产生 HSPI事务 | 在软件、供电、连线均排除后，用另一块 CH569 板做 A/B 对比 |

## 11. 推荐解决方案与执行顺序

### 阶段 A：确认并记录 USB 枚举基线

1. 关闭厂家 Demo、Bus Hound、其他可能占用 WCH 设备的软件；
2. 下载确定版本的 FPGA bitstream；
3. 确认三根控制跳线；
4. 烧录已知哈希的厂家 CH569 HEX；
5. 短按 `USB_RST`，不要按 BOOT；
6. 等待 Windows 枚举完成；
7. 用 UsbTreeView 确认当前实际为 SuperSpeed，并保存截图/报告；
8. 连续观察至少 60 秒，记录设备在线状态；
9. 如需验证复现性，可重复 10 次复位/枚举并记录成功率。此前的 `CM_PROB_PHANTOM` 是关板所致，不作为异常样本统计。

PowerShell 快速检查：

```powershell
Get-PnpDevice -PresentOnly |
  Where-Object InstanceId -match 'VID_1A86&PID_5537' |
  Format-List Status,Class,FriendlyName,InstanceId
```

阶段 A 通过标准：电路板上电时设备为 `Present=True/Status=OK`，实际协商为 SuperSpeed，并且复位后能够重新出现。人为关板后的设备消失属于预期行为。

### 阶段 B：修正上位机测试环境并只验证 EP2

1. 将测试工具改为使用与当前驱动配套的 WCH 3.5 x86 DLL；
2. 核对 P/Invoke 原型；官方 `CH375CloseDevice` 返回 `VOID`，当前 C# 声明为 `bool`，虽不影响本次写入，但应修正；
3. 优先用官方标准批量接口 `CH375WriteData/CH375ReadData` 建立基线，再保留 `WriteEndP/ReadEndP` 作为指定管道诊断；
4. 输出 DLL版本、设备是否当前存在、函数返回值、实际长度和耗时；
5. 测试 1024、4096 两种长度；
6. 任一次实际长度为 0 时立即停止，不进入 EP1 或 ILA 后级判断。

阶段 B 通过标准：EP2 每次实际写入 `4096/4096`，连续 100 次无 0 长度、无掉线。

### 阶段 C：增加 CH569 USB 诊断固件

在不改变协议的诊断版本中增加：

- 启动阶段码：等待 PA12、HSPI 初始化完成、USB3 初始化完成；
- USB link 状态和复位次数；
- EP2 ACK/ERDY 设置次数；
- EP2 回调次数及每次 `nump/rx_len/status`；
- `ENDP2_Rx_Full_Flag` 置位次数；
- 四个阻塞等待的超时；
- 超时后清端点/HSPI状态并重新进入接收，而不是永久死循环；
- `R8_HSPI_INT_FLAG`、`R8_HSPI_RTX_STATUS` 原始值；
- 当前工作在 USB3 还是 USB2。

USB2 路径应修复累计 DMA 地址和完成标志；如果阶段 2 明确只接受 USB3，也可以在 USB2 枚举后返回清晰错误，避免假装可回环。

### 阶段 D：验证 CH569 -> FPGA 的 HSPI 接收

先布防 RX ILA，再运行一次 `Usb3LoopbackTest.exe`：

1. 触发条件首选 `Rx_Ctrl/Rx_En == 1`；
2. 如果控制线异步脉冲难抓，再用 `HRACT == 1`；
3. 检查 `HRCLK` 是否持续且频率正确；
4. 检查帧头；
5. 检查 1024 个 `FIFO_WR_EN`；
6. 比较全部 1024 个 `FIFO_DIN`，不只看前几个字；
7. 检查 `Rx_Done` 恰好一个脉冲；
8. 检查 CRC 尾字没有写入 payload FIFO。

阶段 D 通过标准：4096 字节逐字节完全正确、FIFO 不满、无帧头/CRC混入 payload。

### 阶段 E：验证 FPGA -> CH569 的 HSPI 回传

1. 确认 RX 完成后 FIFO 非空；
2. 触发 `Tx_Ctrl/Tx_En == 1`；
3. 检查 `HTREQ -> HTRDY -> HTVLD` 时序；
4. 检查 `FIFO_RD_EN` 与 `HTD` 的一拍关系；
5. 检查帧头、1024 payload 字和 CRC 尾字；
6. 确认 `Tx_Done`；
7. 从 CH569 读取 `R8_HSPI_RTX_STATUS`。

阶段 E 通过标准：CH569 状态不含 `0x02/0x04`，FPGA发送数据与接收 FIFO 完全一致。

### 阶段 F：统一 CRC 和帧头

优先恢复“CRC 覆盖实际发送的完整帧头和 payload”这一原则：

```verilog
wire_crc_data = Tx_Data;
```

然后用同一组 4096 字节固定测试向量，离线计算 CRC，并同时对比：

- FPGA ILA 看到的 CRC；
- CH569 硬件状态；
- PC 最终读回数据。

如果仍报 `0x04`，单独处理包序号初值、递增和复位同步；不要把序号错误与 CRC错误混在一起修改。

### 阶段 G：端到端稳定性验收

依次运行：

```powershell
Usb3LoopbackTest.exe 1
Usb3LoopbackTest.exe 100
Usb3LoopbackTest.exe 10000
```

记录：

- 成功次数和首个失败序号；
- 每次写/读实际长度；
- 首个字节错误偏移；
- 平均和最低吞吐；
- USB 重连次数；
- CH569 USB/HSPI错误计数；
- FPGA FIFO满、空和溢出计数。

最终回环验收标准：

- 10000 次 4096 字节回环全部逐字节一致；
- 不发生设备掉线或重新枚举；
- 不出现 CRC/序号错误；
- FPGA FIFO 不溢出；
- 重启、重新插拔和重新烧录后结果可复现。

## 12. 下一次继续调试时的最短操作清单

1. 记录准备烧录的 `.bit/.ltx/.hex` 文件名、时间和 SHA-256；
2. 下载 FPGA bitstream；
3. 烧录 CH569 回环 HEX；
4. 短按 `USB_RST`；
5. 确认 PnP 当前存在且 UsbTreeView 显示 SuperSpeed；
6. 确认厂家 Demo 等程序已关闭；
7. 使用 WCH 3.5 x86 DLL版本的 `Usb3LoopbackTest` 运行 1 次；
8. 若 EP2 为 `0/4096`，只查 USB/CH569 EP2，不查 FPGA CRC；
9. 若 EP2 为 `4096/4096` 但 EP1 为 0，读取 CH569阶段码和 `R8_HSPI_RTX_STATUS`，并抓 RX/TX ILA；
10. 若 EP1 为 `4096/4096` 但数据不一致，定位首个错误偏移并检查 HSPI边沿、FIFO对齐和 CRC覆盖范围；
11. 单次通过后再运行 100 次和 10000 次压力测试；
12. 每轮测试把终端输出、PnP状态、固件状态和 ILA CSV 放在同一个带时间戳的目录中。

## 13. 调试时必须避免的误判

- `CH375OpenDevice` 成功不代表 EP2 可写；
- DLL函数返回 `True` 不代表写入完成，必须检查实际长度；
- Windows 显示 `WCH USB3.0 DEVICE` 不代表实际协商速度一定是 SuperSpeed；
- `Rx_En` 没触发时，不能直接判断 HSPI 硬件损坏，必须先确认 EP2 确实写入 4096 字节；
- sticky ILA 为 1 只表示历史上曾出现过信号，不等于当前事务完整；
- EP1 回读 0 可能是 HSPI CRC/序号错误，也可能是 CH569 卡在更前面的等待；
- 更换核心板后现象变化不等于已证明原核心板损坏；
- 反复换线不能替代 UsbTreeView 的实际速度确认和端点测试；
- 修改 FPGA CRC前必须先保存完整线上帧头、payload和尾部 CRC，不应依靠猜测反复修改。

## 14. 当前结论

目前可以确定：

1. FPGA 可编程、ILA 可用；
2. CH569 曾成功枚举，不能直接判定芯片损坏；
3. 两个方向的 HSPI 控制/握手信号历史上都曾出现，板间 HSPI 并非永久完全断路；
4. CH569 -> FPGA 的 HSPI 接收曾推进到 1024 次 FIFO写和 `Rx_Done`，但数据从偏移 `0x58` 起损坏；
5. FPGA -> CH569 的当前有效回传尚未稳定复现；
6. FPGA TX 帧头与 CRC输入存在明确不一致；
7. 最新、最靠前的阻塞点是设备成功连接时 USB EP2 实际写入 `0/4096`；
8. 最新一次“设备不在线/无法打开”的原因是电路板电源关闭，不属于 USB异常掉线；
9. 因此后续不需要重新证明基本枚举是否存在，应先记录实际 SuperSpeed 协商状态并解决 EP2，再继续处理 HSPI数据完整性、CRC和 EP1回传。

在最小回环达到长期稳定之前，不应把 DILA 业务数据、参数协议和连续高速流接入该链路。回环通过后，再将现有统一应用帧放入 4096 字节 HSPI payload，保持 UART 与 USB3.0 共用同一应用层协议。

## 15. 2026-09-09 续调记录：排除上位机 DLL 版本混用

### 15.1 已完成修改

已确认原 `Tools/Usb3LoopbackTest/build.ps1` 每次构建都会强制复制厂家资料中的
`CH375DLL.dll 2.9` 到程序目录。因此即使系统已安装 3.5，Windows 的 DLL 搜索顺序
仍会让测试程序优先加载自身目录中的 2.9。

现已完成：

- 构建脚本改为复制 `C:\Windows\SysWOW64\CH375DLL.DLL`；
- 当前复制并验证的文件版本为 `3.5`；
- SHA-256 为 `0F019B958D4D3F6B8EC0D282EF848A57F0F92A0596D7405B6C58F5AA383A326C`；
- 工具会同时打印候选 DLL 和实际加载 DLL 的完整路径、版本；
- 修正 `CH375CloseDevice` P/Invoke 返回类型为 `void`；
- 增加标准 `CH375WriteData/CH375ReadData`，并将其作为默认基线；
- 保留 `CH375WriteEndP/CH375ReadEndP`，可通过 `--api endpoint` 做 A/B 对比；
- 增加 `--size 1024|4096` 和 `--write-only`；
- 每笔传输输出布尔返回值、实际长度及耗时；
- 已静态确认 3.5 DLL 导出上述两套读写接口。

重新构建已通过。板卡当前未上电，程序能够正确加载程序目录内的 3.5 DLL，随后因
设备 0 不存在而以退出码 5 结束；这属于当前断电状态的预期结果，不是新的故障。

### 15.2 板卡上电后的下一组最小实验

严格按 FPGA bitstream、CH569 固件、`USB_RST`、Windows 枚举的顺序准备后，每次
只运行一条命令；只写诊断会改变 CH569 状态，下一条命令前必须再次短按 `USB_RST`。

```powershell
cd E:\Documents\CH4_Imaging_Code_v2\Tools\Usb3LoopbackTest\bin

# 第一优先级：3.5 DLL + 官方标准批量接口，只判断 EP2
.\Usb3LoopbackTest.exe 1 --api standard --size 4096 --write-only

# USB_RST 后进行同长度端点 API 对照
.\Usb3LoopbackTest.exe 1 --api endpoint --size 4096 --write-only

# 若 4096 都返回 0，再分别用 1024 字节排除 Burst/长度相关问题
.\Usb3LoopbackTest.exe 1 --api standard --size 1024 --write-only
.\Usb3LoopbackTest.exe 1 --api endpoint --size 1024 --write-only
```

解释顺序：

1. `standard=4096/4096` 而 `endpoint=0/4096`：旧端点 API 参数/管道用法问题；后续统一使用标准接口；
2. 两者均为 `4096/4096`：EP2 已通过，立即进入 RX ILA 和 EP1/HSPI 检查；
3. 1024 成功但 4096 失败：重点检查 USB3 Burst level、ERDY、`nump` 和回调完成条件；
4. 四组均为 0：优先读取 CH569 端点阶段码和 USB link 状态，不修改 FPGA CRC；
5. 调用返回 `False`：记录 Windows 错误、驱动占用和设备是否重新枚举，与“返回 True、长度 0”分开处理。

### 15.3 实测结果：EP2 已通过，回传被后级拦截

板卡烧录 `top_hspi_tx_30m_diag.bit` 和厂家 CH569 HEX、复位后，使用 3.5 DLL
及标准批量 API 得到：

```text
WRITE api=WriteData ok=True actual=4096/4096
USB_EP2_WRITE_PASS
```

对同一笔数据随后只读 EP1，结果为 `0/4096`。因此原“EP2 实际写入 0”的最前级
阻塞已经排除，故障位置已经推进到 HSPI 回传或 CH569 CRC/序号校验阶段。

稳定时钟诊断 ILA 显示以下 sticky 位全部为 1：

```text
tx_ctrl_seen = 1
htreq_seen   = 1
htvld_seen   = 1
htrdy_seen   = 1
```

这证明本轮 CH569 已切换到 FPGA 回传阶段，FPGA 产生了请求和有效数据，CH569 也
给出了 ready。EP1 为 0 不是因为发送方向完全没有启动。

修正采集深度后的 RX ILA 成功取得 1024 点。测试向量的开头按 32 位小端格式正确，
但本次从第 21 个数据字，即字节偏移 `0x54` 开始错误：

```text
期望 FIFO_DIN：0x57565554
实际 FIFO_DIN：0xE412C75A
```

随后固定值 `0xE412C75A` 持续若干周期，再出现大量 `0xCAAAAAAA`。后者与 FPGA
TX 帧头标记完全一致，说明接收状态机仍在写 FIFO 时，共享 HD 总线已经出现 FPGA
TX 数据。该现象需要继续检查 `Tx_Ctrl` 到达时刻、共享总线方向切换以及 CH569
实际 HSPI TX 完成时刻，不能只按普通 FIFO 一拍错位解释。

### 15.4 已生成 CRC 恢复版诊断 bitstream

此前诊断源码在线上传输 `C?AAAAAA` 帧头，但 CRC 输入把帧头用户字段替换为 0，
与厂家原版“对实际 `Tx_Data` 计算 CRC”的实现不一致。现已恢复：

```verilog
assign wire_crc_data = Tx_Data;
```

Vivado 重新实现完成，报告显示所有用户时序约束满足。为避免和旧文件混淆，下一轮
使用以下新文件：

```text
top_hspi_tx_30m_diag_crc_wire.bit
SHA-256 = EC8617CCE92CC151972C5DA430291ADB192BF5E8CAD4CACA6C46EE641FD908A3

top_hspi_tx_30m_diag_crc_wire.ltx
SHA-256 = E47AEDCF6A8650BE875C4DC10E98670A4DF4B6A2011B7E36E312D68069A7983D
```

该版本的第一目标是确认 CH569 能否接受回传 CRC 并开放 EP1。即使 EP1 恢复，仍需
根据返回数据和 TX ILA 单独处理 `0x54` 之后的数据损坏及总线方向切换问题。

### 15.5 最终通过：半双工总线切换修复 + 端点 API

2026-09-09 使用无 ILA 的 30 MHz FPGA bitstream、正式 CH569 固件和 CH375DLL
3.5 完成最终测试。关键结论如下：

1. 根因是 FPGA 在 CH569 接收活动 `HRACT` 尚未结束时提前驱动共享 `HD[31:0]`
   总线，导致接收 FIFO 后半段混入 FPGA 帧头并触发 CRC 错误。最终将 IOBUF 输出
   条件改为仅在 `HTREQ && !HRACT` 时驱动，并等待 RX 完成后启动 TX。
2. 上位机必须使用端点专用 API：`CH375WriteEndP(EP2=0x02)` 和
   `CH375ReadEndP(pipe1)`。标准 `CH375ReadData` 在本设备上会返回 `0/4096`，
   不能用来判断 EP1 是否有数据。
3. FPGA 每完成一笔回传，HSPI TX 序号会递增；只复位 CH569 不会清零 FPGA 序号。
   重新下载 FPGA bitstream 后再复位 CH569，才能保证两端序号同步。
4. 诊断固件实测 `status=0x00`、`rx_seq=tx_seq`、`stage=0x05`，证明 CRC、序号和
   HSPI 接收完成均正常。诊断尾部的 16 字节状态字段不属于正式 payload。

最终验收固定使用以下文件：

```text
CH569: E:\Documents\CH4_Imaging_Code_v2\Firmware\CH569\FINAL_TEST_CH569_HSPI_USB_Loopback.hex
SHA-256 = 2C4E2F9BD65A1FDD94D3CC04A87FA8480275D402E7D3BCA1EB6C354A4C2DAFF0

FPGA: E:\Documents\Vivado\ch2_ACX750_CH569_200T_USB30_LoopBack\USB30_LoopBack\bit\FINAL_FPGA_HSPI_30M_HalfDuplexFix_NoILA.bit
SHA-256 = DD8DC4E17E3DD3B3472635918F25659B31F96F0D07702AD26C988E2E136858A1
```

最终正式固件测试输出：

```text
WRITE api=WriteEndP(EP2) ok=True actual=4096/4096
READ api=ReadEndP(pipe1) actual=4096/4096
PASS，写 4096 + 读 4096 字节
USB3_LOOPBACK_PASS：1 次全部通过，平均双向吞吐 9.91 MiB/s
```

当前最小 USB3.0 回环实验已通过。后续若重新下载 FPGA，必须重新复位 CH569；若
连续发送多笔数据，则必须保持 FPGA 和 CH569 的序号状态同步。

### 15.6 主项目可复现黄金基线验收

厂家实测通过的 `Stream_Ctrl`、HSPI RX/TX、CRC32、FIFO Generator 和 Clock Wizard
配置已纳入：

```text
E:\Documents\CH4_Imaging_Code_v2\FPGA\vendor\ch569_loopback_baseline
```

构建入口及输出为：

```text
FPGA\scripts\build_usb3_loopback.tcl
FPGA\build\usb3_loopback\ch4_usb3_loopback.bit
SHA-256 = 71E55D40D9583C59521BCD2F3432E638592619194A55354DF9AF252FD0316064
```

该构建使用30 MHz HSPI TX、`HTREQ && !HRACT`共享总线方向保护、完整RX结束后
再启动TX，并在构建中检查不含ILA/debug hub。最终时序为 WNS `+4.675 ns`、
WHS `+0.113 ns`。配合正式CH569固件的实物测试结果：

```text
WRITE actual=4096/4096
READ  actual=4096/4096
USB3_LOOPBACK_PASS
平均双向吞吐 11.89 MiB/s
```

此前主项目通用重写模块曾先后暴露两个差异：未锁存早于`HRACT`到达的`Rx_Ctrl`
启动脉冲，以及组合读FIFO与厂家标准读FIFO之间3个32位字的预取偏移。阶段2黄金
基线因此固定使用上述厂家模块/IP配置；通用模块仅作为后续连续流重构代码，不作为
当前硬件验收依据。

### 15.7 100 次连续回环稳定性验收

在黄金基线bitstream和正式CH569固件不复位的情况下，连续执行100笔端点API回环，
每笔写入和读回均为4096字节，逐字节校验全部通过：

```text
USB3_LOOPBACK_PASS：100 次全部通过
平均双向吞吐 30.34 MiB/s
```

该结果证明HSPI包序号能够在连续事务间同步递增，链路已达到接入阶段2应用数据的
稳定性门槛。下一检查点使用一帧一个4096字节块的方式封装统一应用帧，未使用区域
补零，并保持已验收的HSPI物理层和CRC逻辑不变。

### 15.8 阶段2单向流式固件初版

新增独立CH569固件源文件`Firmware/CH569/usb3_stream/Main.c`。它不再等待EP2写入，
而是拉高PA15/`Tx_Ctrl`允许FPGA发送，使用HSPI RX DMA接收4096字节；仅当CH569
硬件CRC和包序号检查都正常时，才通过EP1把该块上传给PC。异常块丢弃并继续下一轮，
避免厂家回环代码在错误状态下永久等待。

初版已使用WCH RISC-V GCC 8.2.0完成编译和链接：

```text
E:\Documents\CH4_Imaging_Code_v2\Firmware\CH569\CH569_USB3_Stream.hex
SHA-256 = D23AB869250F8C3F1ECEA4A5CA40B7AF134BF88D2E45D75A06DEBB51F6CE876F
```

该固件不能与原回环bitstream混用。配套的固定融合点流式测试bitstream已生成：

```text
E:\Documents\CH4_Imaging_Code_v2\FPGA\build\usb3_stream_test\ch4_usb3_stream_test.bit
SHA-256 = 657558A1ED0AD2E750E8933DA6C0D8D2FB58E124185084BF336BCB2035E0D66B
```

该镜像每次检测到`Tx_Ctrl`上升沿时，生成一帧61字节的合法`FUSED_POINT`应用帧，
将其余4035字节补零，待完整4096字节进入异步FIFO后才启动已验收的30 MHz厂家
HSPI TX。首次实测发现标准FIFO输出前存在一个32位空字，因此最终版本在启动TX前
增加一次显式预取，并使用不反压上游的一拍延迟复制首字，以匹配厂家TX读时序；
固定短帧的最后一个全零填充字不写入FIFO，使总深度仍为1024字。最终时序WNS为
`+3.015 ns`、WHS为`+0.064 ns`，所有用户时序约束满足，
且不含ILA/debug hub。

硬件联调先执行单块读取，4096字节完整接收，FUSED_POINT帧头、CRC16及尾部零填充
全部通过；随后不复位连续读取100个数据块也全部通过。负载内sequence与point_id
从17连续递增至116，没有丢帧或重复帧，实测平均USB读取吞吐为41.32 MiB/s：

```text
USB3_FUSED_POINT_STREAM_PASS：100 个数据块全部通过，平均读取吞吐 41.32 MiB/s
```

至此，独立CH569流式上传固件、固定融合点FPGA数据源以及上位机读取/协议校验链路
完成第一阶段硬件验收。下一步将固定测试数据源替换为阶段2真实融合结果输入。

### 15.9 阶段2真实融合结果接入

新增`ch4_real_fused_point_source.v`，复用项目现有HITRAN ROM、25.6 MSPS调度、
校准、DILA、滑动平滑、1600点扫描成帧和WMS特征提取链路，生成真实48字节
FUSED_POINT载荷。`usb_fused_point_stream_bridge.v`使用16深度、384位双时钟
FIFO完成50 MHz成像域到120 MHz USB打包域的跨时钟传输，并统计接受、启动发送
和丢弃帧数。每次CH569拉高`Tx_Ctrl`时仅取出一帧，保持一请求对应一个HSPI块。

新系统顶层`ch4_usb3_imaging_stream_top.v`保留已验收的30 MHz厂家HSPI TX、
4096字节块格式以及FIFO显式预取对齐。真实数据bitstream独立输出，不覆盖黄金版本：

```text
E:\Documents\CH4_Imaging_Code_v2\FPGA\build\usb3_imaging_stream\ch4_usb3_imaging_stream.bit
SHA-256 = 620FB89DDC9BC92D11198E23025772E7D46F937644C5C72725DF28431AEBB1DF
```

异步FIFO时钟域已显式声明；最终实现WNS为`+2.069 ns`、WHS为`+0.048 ns`，
无时序违例、无组合环和未布线网络。配套CH569固件仍使用
`CH569_USB3_Stream.hex`，无需重新生成。
