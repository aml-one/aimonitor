# generate_icon.ps1
# Run from the WindowsClient directory on Windows to produce Assets\AppIcon.ico
# Requires .NET / System.Drawing (available on any Windows machine with .NET installed)
#
# Usage:
#   cd WindowsClient
#   powershell -ExecutionPolicy Bypass -File generate_icon.ps1

param(
    [string]$SourcePng = "..\AiMonitor\Assets.xcassets\AppIcon.appiconset\icon_256x256.png"
)

Add-Type -AssemblyName System.Drawing

$outputIco = "Assets\AppIcon.ico"
New-Item -ItemType Directory -Force -Path "Assets" | Out-Null

if (-not (Test-Path $SourcePng)) {
    Write-Error "Source PNG not found: $SourcePng"
    exit 1
}

$sourceImage = [System.Drawing.Image]::FromFile((Resolve-Path $SourcePng).Path)

# Sizes to embed in the ICO (256 → stored as 0 per ICO spec)
$sizes = @(16, 24, 32, 48, 64, 128, 256)

# Render each size to PNG bytes
$pngDatas = foreach ($size in $sizes) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.CompositingQuality= [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.DrawImage($sourceImage, 0, 0, $size, $size)
    $g.Dispose()

    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    , $ms.ToArray()   # comma prevents PowerShell from unwrapping single-element arrays
}
$sourceImage.Dispose()

# ── Build ICO binary ─────────────────────────────────────────────────────────
# Format: ICONDIR (6 bytes) + count × ICONDIRENTRY (16 bytes each) + PNG blobs
$stream = New-Object System.IO.MemoryStream
$writer = New-Object System.IO.BinaryWriter($stream)

# ICONDIR header
$writer.Write([uint16]0)              # reserved
$writer.Write([uint16]1)              # type = icon
$writer.Write([uint16]$sizes.Count)   # image count

# ICONDIRENTRY array
$dataOffset = 6 + $sizes.Count * 16

for ($i = 0; $i -lt $sizes.Count; $i++) {
    $sz      = $sizes[$i]
    $szByte  = if ($sz -eq 256) { 0 } else { $sz }   # ICO encodes 256 as 0
    $pngLen  = $pngDatas[$i].Length

    $writer.Write([byte]$szByte)      # width
    $writer.Write([byte]$szByte)      # height
    $writer.Write([byte]0)            # color count (0 = true colour)
    $writer.Write([byte]0)            # reserved
    $writer.Write([uint16]1)          # planes
    $writer.Write([uint16]32)         # bit depth
    $writer.Write([uint32]$pngLen)    # data size
    $writer.Write([uint32]$dataOffset)# offset to data

    $dataOffset += $pngLen
}

# PNG blobs
foreach ($blob in $pngDatas) {
    $writer.Write($blob)
}

$writer.Flush()
[System.IO.File]::WriteAllBytes((Join-Path $PSScriptRoot $outputIco), $stream.ToArray())
$stream.Dispose()

Write-Host "✓  $outputIco generated with $($sizes.Count) sizes: $($sizes -join ', ')px"
