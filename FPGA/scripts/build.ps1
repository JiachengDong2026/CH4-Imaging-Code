param([switch]$RunProtocolTest)

$ErrorActionPreference = 'Stop'
$FpgaRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ProjectRoot = Split-Path -Parent $FpgaRoot
$Vivado = 'D:\Software\Vivado\Vivado\2020.2\bin\vivado.bat'
$BuildRoot = Join-Path $FpgaRoot 'build'
New-Item -ItemType Directory -Force -Path $BuildRoot | Out-Null
if (-not (Test-Path -LiteralPath $Vivado)) { throw "未找到 Vivado 2020.2：$Vivado" }

function Invoke-Vivado([string]$ScriptName, [string]$LogStem) {
    $Script = Join-Path $FpgaRoot "scripts/$ScriptName"
    $Log = Join-Path $BuildRoot "$LogStem.log"
    $Journal = Join-Path $BuildRoot "$LogStem.jou"
    Push-Location $ProjectRoot
    try {
        & $Vivado -mode batch -log $Log -journal $Journal -source $Script
        if ($LASTEXITCODE -ne 0) { throw "Vivado 执行失败：$ScriptName；见 $Log" }
    } finally { Pop-Location }
}

Invoke-Vivado 'check_syntax.tcl' 'syntax'
if ($RunProtocolTest) { Invoke-Vivado 'run_protocol_test.tcl' 'protocol_sim' }
Write-Host 'FPGA 阶段 0 构建检查通过。' -ForegroundColor Green
