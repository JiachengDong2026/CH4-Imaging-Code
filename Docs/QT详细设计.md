# Qt 上位机详细设计

## 阶段 0 基线

- Qt 6.11.2、MinGW 13.1 64-bit、C++20、CMake、Ninja；
- 白色 Qt Widgets 多页面骨架；
- `frame_codec` 实现小端编解码、CRC、拆包、粘包、垃圾字节丢弃和错误恢复；
- 协议与寄存器常量由共享定义生成；
- VS Code 使用 CMake 的 `compile_commands.json`，Code Runner 执行项目级构建与运行；
- Release 通过 `windeployqt` 复制 Qt 与 MinGW 运行库。

## 阶段 1 类边界

```text
UI 线程：页面、状态、限频后的图形刷新
DeviceSession：连接状态、命令序号、超时、重试、版本核对
SerialTransport / MockTransport：字节收发
Services：快反镜、DILA、采集状态机
Processing：A1/A2、A2/A1、坐标标定、网格重建
SessionRecorder：独立工作线程，持续写入项目 Data 目录
```

接收线程只解析和投递数据，不直接重画界面；绘图刷新限制在 20～30 FPS。未完成真实标定前，界面只允许显示“相对甲烷信号”或“仿真浓度”。

