# CH4 Imaging Qt host

Qt 6.11.2、MinGW 64-bit、C++20 上位机。阶段 1 已接入白色多页面界面、统一协议、原生 Windows 串口、Mock 下位机、轨迹/谐波/甲烷图像和项目内会话记录。

```powershell
.\tools\build.ps1 -Config Debug -Test
.\tools\run.ps1 -Config Debug
```

发布：

```powershell
.\tools\package.ps1
```

脚本显式使用 `C:/Qt/6.11.2/mingw_64` 与配套 MinGW/Ninja，不读取 Anaconda 的 Qt。VS Code 配置位于 `.vscode`，`Ctrl+Shift+B` 编译，`F5` 调试；Code Runner 对 C++ 文件执行项目级构建与运行。
