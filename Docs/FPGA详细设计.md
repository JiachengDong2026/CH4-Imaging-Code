# FPGA 详细设计

## 阶段 0 基线

目标器件为 `xc7a200tfbg484-2`，主时钟 50 MHz。顶层 `ch4_imaging_top` 目前连接：

```text
复位按键 → reset_sync
50 MHz → system_timebase（64 位、20 ns/tick）
UART_RXD → uart_rx（921600 8N1）→ app_frame_rx（统一应用帧）
UART_TXD → 空闲高电平（阶段 1 接入响应调度器）
```

综合和仿真只使用 Verilog-2001。协议常量由 `Shared/protocol.yaml` 生成，RTL 不手写消息号。

## 阶段 1 接口约定

- 模块数据通路统一采用 `valid/ready`；不能直接读取其他业务模块内部寄存器；
- 所有事件和数据使用同一个 64 位时间计数器；
- 配置写 shadow bank，经范围/组合检查后在扫描或光谱安全边界整体提交；
- ROM 和后续 ADC 都输出带 `sample_valid` 的有符号 16 位样本；
- DILA 默认不因上行链路反压而停顿，满缓冲时按数据类型统计丢弃；
- 快反镜 9 字节原生帧只存在于 FPGA 与驱动器之间，不上传给 Qt 作为业务协议。

## 引脚状态

阶段 0 只冻结 W19 时钟、D21 复位、L21/M21 板载 UART。快反镜 C18/C19、E19/D19 会在确认外部 RS-422 收发器、极性、终端和 Bank 电压后于阶段 1 启用。

