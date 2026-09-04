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

if (-not (Test-Path -LiteralPath $CMake)) {
    throw "Qt CMake was not found: $CMake"
}

Push-Location $QtRoot
try {
    & $CMake --preset "qt-$Preset"
    if ($LASTEXITCODE -ne 0) { throw 'Qt CMake configuration failed.' }

    & $CMake --build --preset $Preset
    if ($LASTEXITCODE -ne 0) { throw 'Qt build failed.' }

    if ($Test) {
        & $CTest --preset $Preset
        if ($LASTEXITCODE -ne 0) { throw 'Qt tests failed.' }
    }
} finally {
    Pop-Location
}

$CompileCommands = Join-Path $QtRoot "build/$Preset/compile_commands.json"
if (Test-Path -LiteralPath $CompileCommands) {
    Copy-Item -Force -LiteralPath $CompileCommands -Destination (Join-Path $QtRoot 'compile_commands.json')
}

Write-Host "Qt $Config build complete." -ForegroundColor Green
