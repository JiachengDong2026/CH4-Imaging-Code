param(
    [ValidateSet('Debug', 'Release')]
    [string]$Config = 'Debug'
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ProjectRoot 'QT/tools/run.ps1') -Config $Config

