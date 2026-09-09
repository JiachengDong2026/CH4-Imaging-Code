$ErrorActionPreference = 'Stop'

$toolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $toolRoot '..\..'))
$outputDir = Join-Path $toolRoot 'bin'
$sourceFile = Join-Path $toolRoot 'Usb3LoopbackTest.cs'
$compiler = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe'
$windowsDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
$driverDll = Join-Path $windowsDirectory 'SysWOW64\CH375DLL.DLL'
$program = Join-Path $outputDir 'Usb3LoopbackTest.exe'

if (-not (Test-Path -LiteralPath $compiler)) {
    throw "C# compiler not found: $compiler"
}
if (-not (Test-Path -LiteralPath $driverDll)) {
    throw "Installed x86 CH375 DLL not found: $driverDll. Install the current WCH CH372/CH375 driver package first."
}

$dllVersion = (Get-Item -LiteralPath $driverDll).VersionInfo.FileVersion
$dllHash = (Get-FileHash -LiteralPath $driverDll -Algorithm SHA256).Hash

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
& $compiler /nologo /target:exe /platform:x86 /optimize+ /out:$program $sourceFile
if ($LASTEXITCODE -ne 0) {
    throw "Compiler failed with exit code $LASTEXITCODE"
}

Copy-Item -LiteralPath $driverDll -Destination (Join-Path $outputDir 'CH375DLL.dll') -Force
Write-Host "BUILD_PASS $program"
Write-Host "DLL_SOURCE $driverDll"
Write-Host "DLL_VERSION $dllVersion"
Write-Host "DLL_SHA256 $dllHash"
