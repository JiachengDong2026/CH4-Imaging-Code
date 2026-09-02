$ErrorActionPreference = 'Stop'
$QtRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ProjectRoot = Split-Path -Parent $QtRoot
$DistRoot = [System.IO.Path]::GetFullPath((Join-Path $QtRoot 'dist'))
$PackageDir = [System.IO.Path]::GetFullPath((Join-Path $DistRoot 'CH4-Imaging-Control'))
if (-not $PackageDir.StartsWith($DistRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw '发布目录解析结果越出 QT/dist，已停止。'
}
& (Join-Path $QtRoot 'tools/build.ps1') -Config Release -Test

if (Test-Path -LiteralPath $PackageDir) { Remove-Item -Recurse -Force -LiteralPath $PackageDir }
New-Item -ItemType Directory -Force -Path $PackageDir | Out-Null
$Executable = Join-Path $QtRoot 'build/release/CH4-Imaging-Control.exe'
Copy-Item -LiteralPath $Executable -Destination $PackageDir
& 'C:\Qt\6.11.2\mingw_64\bin\windeployqt.exe' --release --compiler-runtime --no-translations (Join-Path $PackageDir 'CH4-Imaging-Control.exe')
if ($LASTEXITCODE -ne 0) { throw 'windeployqt 发布失败。' }
Write-Host "可直接运行的发布目录：$PackageDir" -ForegroundColor Green

