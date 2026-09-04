param(
    [ValidateSet('All', 'Generate', 'Test', 'Qt', 'Fpga', 'Bitstream', 'Package')]
    [string]$Target = 'All',
    [ValidateSet('Debug', 'Release')]
    [string]$Config = 'Debug'
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PythonExe = (Get-Command python -ErrorAction Stop).Source

function Invoke-Generator {
    & $PythonExe (Join-Path $ProjectRoot 'Tools/protocol_generator/generate.py')
    if ($LASTEXITCODE -ne 0) { throw '协议生成失败。' }
}

function Invoke-PythonTests {
    & $PythonExe (Join-Path $ProjectRoot 'Tools/protocol_generator/selftest.py')
    if ($LASTEXITCODE -ne 0) { throw '共享协议自检失败。' }
}

function Invoke-QtBuild {
    & (Join-Path $ProjectRoot 'QT/tools/build.ps1') -Config $Config -Test
}

function Invoke-FpgaBuild {
    & (Join-Path $ProjectRoot 'FPGA/scripts/build.ps1') -RunTests
}

switch ($Target) {
    'Generate' { Invoke-Generator }
    'Test' {
        Invoke-Generator
        Invoke-PythonTests
        Invoke-QtBuild
    }
    'Qt' {
        Invoke-Generator
        Invoke-QtBuild
    }
    'Fpga' {
        Invoke-Generator
        Invoke-FpgaBuild
    }
    'Bitstream' {
        Invoke-Generator
        & (Join-Path $ProjectRoot 'FPGA/scripts/build.ps1') -Bitstream
    }
    'Package' {
        Invoke-Generator
        & (Join-Path $ProjectRoot 'QT/tools/package.ps1')
    }
    'All' {
        Invoke-Generator
        Invoke-PythonTests
        Invoke-QtBuild
        Invoke-FpgaBuild
    }
}

Write-Host "项目目标 '$Target' 完成。" -ForegroundColor Green
