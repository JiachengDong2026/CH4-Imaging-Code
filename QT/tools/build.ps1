param(
    [ValidateSet('Debug', 'Release')]
    [string]$Config = 'Debug',
    [switch]$Test
)

$ErrorActionPreference = 'Stop'
$QtRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$CMake = 'C:\Qt\Tools\CMake_64\bin\cmake.exe'
$CTest = 'C:\Qt\Tools\CMake_64\bin\ctest.exe'
$Preset = if ($Config -eq 'Debug') { 'debug' } else { 'release' }
if (-not (Test-Path -LiteralPath $CMake)) { throw "未找到 Qt 配套 CMake：$CMake" }

Push-Location $QtRoot
try {
    & $CMake --preset "qt-$Preset"
    if ($LASTEXITCODE -ne 0) { throw 'Qt CMake 配置失败。' }
    & $CMake --build --preset $Preset
    if ($LASTEXITCODE -ne 0) { throw 'Qt 编译失败。' }
    if ($Test) {
        & $CTest --preset $Preset
        if ($LASTEXITCODE -ne 0) { throw 'Qt 自动测试失败。' }
    }
} finally { Pop-Location }

$CompileCommands = Join-Path $QtRoot "build/$Preset/compile_commands.json"
if (Test-Path -LiteralPath $CompileCommands) {
    Copy-Item -Force -LiteralPath $CompileCommands -Destination (Join-Path $QtRoot 'compile_commands.json')
}
Write-Host "Qt $Config 构建完成。" -ForegroundColor Green

