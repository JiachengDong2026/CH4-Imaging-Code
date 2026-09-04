$ErrorActionPreference = 'Stop'
$FpgaRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ProjectRoot = Split-Path -Parent $FpgaRoot
$Vivado = 'D:\Software\Vivado\Vivado\2020.2\bin\vivado.bat'
$Bitstream = [System.IO.Path]::GetFullPath((Join-Path $FpgaRoot 'build/bitstream/ch4_imaging.bit'))
$AllowedRoot = [System.IO.Path]::GetFullPath((Join-Path $FpgaRoot 'build/bitstream'))
if (-not $Bitstream.StartsWith($AllowedRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Bitstream path is outside the build directory.' }
if (-not (Test-Path -LiteralPath $Bitstream)) { throw "Bitstream not found: $Bitstream" }
Push-Location $ProjectRoot
try {
    & $Vivado -mode batch -log (Join-Path $FpgaRoot 'build/program.log') -journal (Join-Path $FpgaRoot 'build/program.jou') -source (Join-Path $FpgaRoot 'scripts/program_fpga.tcl')
    if ($LASTEXITCODE -ne 0) { throw 'FPGA programming failed; check JTAG connection and program.log.' }
} finally { Pop-Location }
