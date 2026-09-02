# CH4 Imaging Code v2

基于快反镜与 TDLAS-WMS 的甲烷扫描成像系统。当前完成阶段 0：工程骨架和统一协议冻结。

## 当前可用内容

- `Shared/` 是协议、寄存器和固定测试帧的唯一数据源；
- `Tools/protocol_generator/` 从共享定义生成 FPGA、C++ 常量及两份协议文档；
- `FPGA/` 包含可综合的 Artix-7 工程骨架和协议接收单元测试；
- `QT/` 包含 Qt 6.11.2 / C++20 白色界面骨架、协议库和自动测试；
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

设计范围和后续阶段见 [Docs/总体方案设计.md](Docs/总体方案设计.md)，阶段 0 交付说明见 [Docs/阶段0交付说明.md](Docs/阶段0交付说明.md)。
