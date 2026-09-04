# CH4 Imaging Code v2

基于快反镜与 TDLAS-WMS 的甲烷扫描成像系统。阶段 0 已完成并提交，阶段 1 的 UART 仿真闭环正在开发。

## 当前可用内容

- `Shared/` 是协议、寄存器和固定测试帧的唯一数据源；
- `Tools/protocol_generator/` 从共享定义生成 FPGA、C++ 常量及两份协议文档；
- `FPGA/` 已接入 25.6 MSPS HITRAN ROM、1f/2f DILA、特征提取、融合点和 UART 命令/数据链；
- `QT/` 已提供 Mock/真实串口连接、轨迹、谐波、A2/A1 图像和会话 CSV 记录；
- 所有构建、测试、发布和运行输出都留在本项目目录内。

## 一键验证

在项目根目录运行：

```powershell
.\Build.ps1 -Target All -Config Debug
```

常用目标：

```powershell
.\Build.ps1 -Target Generate       # 重新生成两端协议常量和文档
.\Build.ps1 -Target Test           # Python 协议检查 + Qt 协议测试
.\Build.ps1 -Target Fpga           # FPGA 语法/综合检查 + 协议仿真
.\Build.ps1 -Target Bitstream      # 生成板载 UART 通信测试比特流
.\Build.ps1 -Target Qt -Config Debug
.\Build.ps1 -Target Package -Config Release
.\Run.ps1                          # 构建并运行 Debug 上位机
```

工具路径固定为需求指定的 Qt 6.11.2 MinGW 和 Vivado 2020.2；脚本不依赖系统 `PATH` 中的 Anaconda Qt。

## 目录约定

- `FPGA/build`、`FPGA/vivado`：FPGA 生成文件；
- `QT/build`、`QT/dist`：Qt 构建和发布文件；
- `Data`：上位机运行数据；
- `QT/src/protocol/generated_*.h`、`FPGA/rtl/protocol/protocol_defs.vh`：两端生成常量；
- `Shared/test_vectors`、`FPGA/sim/generated_protocol_vectors.vh`：两端共用的生成测试向量。

设计范围和后续阶段见 [Docs/总体方案设计.md](Docs/总体方案设计.md)，阶段 0 交付说明见 [Docs/阶段0交付说明.md](Docs/阶段0交付说明.md)，阶段 1 当前边界见 [Docs/阶段1开发记录.md](Docs/阶段1开发记录.md)。
