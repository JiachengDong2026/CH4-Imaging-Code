# FPGA stage 0

Artix-7 `xc7a200tfbg484-2`、50 MHz 工程骨架。当前顶层只连接复位、统一 64 位时间基准、板载 UART 接收和统一应用帧解析；扫描、DILA、融合在阶段 1 接入。

```powershell
.\scripts\build.ps1 -RunProtocolTest
```

脚本使用需求指定的 Vivado 2020.2，所有工程、日志和仿真结果写入 `FPGA/build` 或 `FPGA/vivado`。

创建可在 Vivado GUI 打开的工程：

```powershell
& 'D:\Software\Vivado\Vivado\2020.2\bin\vivado.bat' -mode batch -source scripts/create_project.tcl
```

