param(
    [string]$OutDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
if (-not $OutDir) {
    $OutDir = Join-Path $root "assets"
}

Add-Type -AssemblyName System.Drawing

function New-Dir([string]$Path) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Draw-CenteredText([System.Drawing.Graphics]$Graphics, [System.Drawing.RectangleF]$Box, [string]$Text, [System.Drawing.Font]$Font, [System.Drawing.Brush]$Brush) {
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = [System.Drawing.StringAlignment]::Center
    $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
    $Graphics.DrawString($Text, $Font, $Brush, $Box, $fmt)
    $fmt.Dispose()
}

function Save-WebLogo([string]$Path, [int]$Width, [int]$Height, [string]$Text) {
    $bmp = New-Object System.Drawing.Bitmap $Width, $Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $fontSize = if ($Width -gt 200) { [single]($Height * 0.58) } else { [single]($Height * 0.68) }
    $font = New-Object System.Drawing.Font("Arial", $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $accent = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 28, 212, 132))
    $white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)

    $pad = [Math]::Max(2, [int]($Height * 0.08))
    Draw-CenteredText $g ([System.Drawing.RectangleF]::new($pad, 0, $Width - (2 * $pad), $Height - $pad)) $Text $font $white
    $g.FillRectangle($accent, $pad, $Height - [Math]::Max(2, [int]($Height * 0.08)), $Width - (2 * $pad), [Math]::Max(2, [int]($Height * 0.05)))

    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $accent.Dispose()
    $white.Dispose()
    $font.Dispose()
    $g.Dispose()
    $bmp.Dispose()
}

function Convert-RgbTo565([System.Drawing.Color]$Color) {
    $r = [int][Math]::Round($Color.R * 31 / 255)
    $g = [int][Math]::Round($Color.G * 63 / 255)
    $b = [int][Math]::Round($Color.B * 31 / 255)
    return (($r -shl 11) -bor ($g -shl 5) -bor $b)
}

function Save-Rgb565Raw([System.Drawing.Bitmap]$Bitmap, [string]$Path) {
    $bytes = New-Object byte[] ($Bitmap.Width * $Bitmap.Height * 2)
    $i = 0
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            $v = Convert-RgbTo565 $Bitmap.GetPixel($x, $y)
            $bytes[$i++] = [byte]($v -band 0xff)
            $bytes[$i++] = [byte](($v -shr 8) -band 0xff)
        }
    }
    [IO.File]::WriteAllBytes($Path, $bytes)
}

function Save-OledLogo([string]$PreviewPath, [string]$RawPath, [int]$Width, [int]$Height) {
    $bmp = New-Object System.Drawing.Bitmap $Width, $Height, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::Black)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::SingleBitPerPixelGridFit

    $fontSize = if ($Width -le 40) { [single]($Height * 0.95) } else { [single]($Height * 0.9) }
    $font = New-Object System.Drawing.Font("Arial", $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $orange = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 92, 60))
    $red = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 122, 12, 12))
    $green = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 28, 212, 132))

    $g.FillRectangle($red, 0, 0, $Width, $Height)
    $g.FillRectangle([System.Drawing.Brushes]::Black, 1, 1, $Width - 2, $Height - 2)
    Draw-CenteredText $g ([System.Drawing.RectangleF]::new(0, -1, $Width, $Height)) "GG" $font $orange
    $dot = [Math]::Max(1, [int]($Height / 8))
    $g.FillRectangle($green, $Width - (2 * $dot), $dot, $dot, $dot)

    $bmp.Save($PreviewPath, [System.Drawing.Imaging.ImageFormat]::Png)
    Save-Rgb565Raw $bmp $RawPath

    $orange.Dispose()
    $red.Dispose()
    $green.Dispose()
    $font.Dispose()
    $g.Dispose()
    $bmp.Dispose()
}

function Save-Favicon([string]$Path) {
    $size = 32
    $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $bg = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 24, 24, 24))
    $accent = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 92, 60))
    $green = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 28, 212, 132))
    $font = New-Object System.Drawing.Font("Arial", 16, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)

    $g.FillRectangle($bg, 0, 0, $size, $size)
    $g.FillRectangle($green, 25, 4, 4, 4)
    Draw-CenteredText $g ([System.Drawing.RectangleF]::new(1, 1, 30, 30)) "GG" $font $accent

    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $font.Dispose()
    $bg.Dispose()
    $accent.Dispose()
    $green.Dispose()
    $g.Dispose()
    $bmp.Dispose()
}

function Save-AppPanel([string]$Path, [int]$Width, [int]$Height, [string]$Text) {
    $bmp = New-Object System.Drawing.Bitmap $Width, $Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $bg = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 18, 18, 18))
    $accent = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 92, 60))
    $green = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 28, 212, 132))
    $white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
    $font = New-Object System.Drawing.Font("Arial", [single]($Height * 0.22), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $smallFont = New-Object System.Drawing.Font("Arial", [single]($Height * 0.11), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)

    $g.FillRectangle($bg, 0, 0, $Width, $Height)
    $g.FillRectangle($green, 0, 0, [Math]::Max(4, [int]($Width * 0.025)), $Height)
    Draw-CenteredText $g ([System.Drawing.RectangleF]::new(0, [single]($Height * 0.08), $Width, [single]($Height * 0.42))) $Text $font $accent
    Draw-CenteredText $g ([System.Drawing.RectangleF]::new(0, [single]($Height * 0.53), $Width, [single]($Height * 0.22))) "GG Router Web UI" $smallFont $white

    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $font.Dispose()
    $smallFont.Dispose()
    $bg.Dispose()
    $accent.Dispose()
    $green.Dispose()
    $white.Dispose()
    $g.Dispose()
    $bmp.Dispose()
}

$webDir = Join-Path $OutDir "web"
$phoneDir = Join-Path $webDir "phone"
New-Dir $OutDir
New-Dir $webDir
New-Dir $phoneDir

Save-WebLogo (Join-Path $webDir "logo_small.png") 111 42 "GG"
Save-WebLogo (Join-Path $webDir "logo_big.png") 130 49 "GG"
Save-WebLogo (Join-Path $phoneDir "logo.png") 400 100 "GG Router"
Save-Favicon (Join-Path $webDir "favicon.png")
Save-AppPanel (Join-Path $webDir "app.png") 170 75 "GG"
Save-AppPanel (Join-Path $phoneDir "app.png") 705 264 "GG"

Save-OledLogo (Join-Path $OutDir "gg_logo_38x14.png") (Join-Path $OutDir "gg_logo_38x14.raw") 38 14
Save-OledLogo (Join-Path $OutDir "gg_logo_81x30.png") (Join-Path $OutDir "gg_logo_81x30.raw") 81 30

Get-ChildItem -LiteralPath $OutDir -Recurse -File |
    Where-Object { $_.Name -match 'logo|gg_logo' } |
    Select-Object FullName, Length
