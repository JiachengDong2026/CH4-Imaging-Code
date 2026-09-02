param(
    [ValidateSet('Debug', 'Release')]
    [string]$Config = 'Debug'
)

$ErrorActionPreference = 'Stop'
$QtRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Preset = if ($Config -eq 'Debug') { 'debug' } else { 'release' }
& (Join-Path $QtRoot 'tools/build.ps1') -Config $Config
$env:Path = "C:\Qt\6.11.2\mingw_64\bin;C:\Qt\Tools\mingw1310_64\bin;$env:Path"
$Executable = Join-Path $QtRoot "build/$Preset/CH4-Imaging-Control.exe"
if (-not (Test-Path -LiteralPath $Executable)) { throw "未找到上位机：$Executable" }
& $Executable

