# CH569 USB3 单向流式上传固件

本目录是阶段2主数据通道固件，不覆盖已经通过硬件验收的
`FINAL_TEST_CH569_HSPI_USB_Loopback.hex`。

```text
FPGA -> HSPI RX DMA -> CH569 4096字节缓冲区 -> USB3 EP1 IN -> PC
```

第一版只实现数据上行。UART继续承担控制命令，USB EP2控制通道留到后续检查点。
CH569在PA15/`Tx_Ctrl`上产生上升沿，接收FPGA的一整个HSPI事务；CRC和包序号均正确
时才开放EP1。错误块直接丢弃，下一轮重新接收，避免厂家回环代码因错误永久阻塞。

`Main.c`作为厂家CH569 USB3工程的替换入口，依赖配套工程中的`USB20`、`USB30`、
启动文件、CH569外设库和闭源`CH56xUSB30_LIB`。构建输出命名为
`CH569_USB3_Stream.hex`，不得覆盖正式回环HEX。
