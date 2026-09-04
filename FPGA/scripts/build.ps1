param([switch]$RunTests, [switch]$Bitstream)

$ErrorActionPreference = 'Stop'
$FpgaRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ProjectRoot = Split-Path -Parent $FpgaRoot
$Vivado = 'D:\Software\Vivado\Vivado\2020.2\bin\vivado.bat'
$BuildRoot = Join-Path $FpgaRoot 'build'
New-Item -ItemType Directory -Force -Path $BuildRoot | Out-Null
if (-not (Test-Path -LiteralPath $Vivado)) { throw "Vivado 2020.2 not found: $Vivado" }

function Invoke-Vivado([string]$ScriptName, [string]$LogStem) {
    $Script = Join-Path $FpgaRoot "scripts/$ScriptName"
    $Log = Join-Path $BuildRoot "$LogStem.log"
    $Journal = Join-Path $BuildRoot "$LogStem.jou"
    Push-Location $ProjectRoot
    try {
        & $Vivado -mode batch -log $Log -journal $Journal -source $Script
        if ($LASTEXITCODE -ne 0) { throw "Vivado failed: $ScriptName; see $Log" }
    } finally { Pop-Location }
}

if (-not $Bitstream -or $RunTests) { Invoke-Vivado 'check_syntax.tcl' 'syntax' }
if ($RunTests) {
    Invoke-Vivado 'run_protocol_test.tcl' 'protocol_sim'
    Invoke-Vivado 'run_stage1_test.tcl' 'stage1_sim'
}
if ($Bitstream) {
    Invoke-Vivado 'run_uart_comm_test.tcl' 'uart_comm_sim'
    Invoke-Vivado 'build_bitstream.tcl' 'bitstream'
}
Write-Host 'FPGA stage 1 build check completed.' -ForegroundColor Green
