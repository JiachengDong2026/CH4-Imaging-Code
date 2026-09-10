param(
    [string]$VendorProject = "E:\Documents\Vivado\ch2_ACX750_CH569_200T_USB30_LoopBack\HSPI_USB_Loopback",
    [string]$ToolchainBin = "E:\Documents\CH4_Imaging_Code_v2\tmp\ch569_toolchain\bin"
)

$ErrorActionPreference = "Stop"
$firmwareDir = Split-Path -Parent $PSScriptRoot
$gcc = Join-Path $ToolchainBin "riscv-none-embed-gcc.exe"
$objcopy = Join-Path $ToolchainBin "riscv-none-embed-objcopy.exe"
$mainObject = Join-Path $PSScriptRoot "Main.o"
$elf = Join-Path $PSScriptRoot "CH569_USB3_Stream.elf"
$hex = Join-Path $firmwareDir "CH569_USB3_Stream.hex"

if (!(Test-Path -LiteralPath $gcc)) {
    throw "找不到CH569 GCC：$gcc"
}
if (!(Test-Path -LiteralPath $VendorProject)) {
    throw "找不到厂家CH569工程：$VendorProject"
}

$includeArgs = @(
    "-I$VendorProject\User",
    "-I$VendorProject\USB20",
    "-I$VendorProject\USB30",
    "-I$VendorProject\SRC\RVMSIS",
    "-I$VendorProject\SRC\Peripheral\inc"
)
$commonArgs = @(
    "-march=rv32imac", "-mabi=ilp32", "-msmall-data-limit=8",
    "-mno-save-restore", "-Os"
)

& $gcc @commonArgs -fsigned-char -ffunction-sections -fdata-sections -g `
    -DDEBUG=1 @includeArgs -c -o $mainObject (Join-Path $PSScriptRoot "Main.c")
if ($LASTEXITCODE -ne 0) { throw "Main.c编译失败，退出码 $LASTEXITCODE" }

$objects = Get-ChildItem -LiteralPath (Join-Path $VendorProject "obj") `
    -Recurse -Filter "*.o" | Where-Object Name -ne "Main.o" | ForEach-Object FullName
$linkerScript = Join-Path $VendorProject "SRC\Ld\Link.ld"
$usb3Library = Join-Path $VendorProject "USB30\libCH56x_usb30.a"

& $gcc @commonArgs -nostartfiles "--specs=nano.specs" "--specs=nosys.specs" `
    "-Wl,--gc-sections" -T $linkerScript -o $elf $mainObject @objects $usb3Library
if ($LASTEXITCODE -ne 0) { throw "固件链接失败，退出码 $LASTEXITCODE" }

& $objcopy -O ihex $elf $hex
if ($LASTEXITCODE -ne 0) { throw "HEX生成失败，退出码 $LASTEXITCODE" }

$file = Get-Item -LiteralPath $hex
$hash = Get-FileHash -LiteralPath $hex -Algorithm SHA256
Write-Host "CH569 stream firmware: $($file.FullName)"
Write-Host "Size: $($file.Length) bytes"
Write-Host "SHA256: $($hash.Hash)"
