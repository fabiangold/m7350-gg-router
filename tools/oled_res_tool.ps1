param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("inspect", "export", "patch")]
    [string]$Command,

    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string]$OutDir = ".\oled_res_export",
    [string]$OutputPath,
    [string]$RawPath,
    [int[]]$Ids,
    [switch]$All,
    [switch]$FullScreenOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-U16LE([byte[]]$Bytes, [int]$Offset) {
    return [BitConverter]::ToUInt16($Bytes, $Offset)
}

function Read-U32LE([byte[]]$Bytes, [int]$Offset) {
    return [BitConverter]::ToUInt32($Bytes, $Offset)
}

function Write-U16LE([byte[]]$Bytes, [int]$Offset, [int]$Value) {
    $tmp = [BitConverter]::GetBytes([UInt16]$Value)
    [Array]::Copy($tmp, 0, $Bytes, $Offset, 2)
}

function Write-U32LE([byte[]]$Bytes, [int]$Offset, [UInt32]$Value) {
    $tmp = [BitConverter]::GetBytes($Value)
    [Array]::Copy($tmp, 0, $Bytes, $Offset, 4)
}

function Get-OledEntries([byte[]]$Bytes) {
    $declaredCount = Read-U32LE $Bytes 0
    $offset = 0x15e
    $entries = @()

    while ($offset + 28 -le $Bytes.Length) {
        $id = Read-U32LE $Bytes $offset
        $x = Read-U16LE $Bytes ($offset + 4)
        $y = Read-U16LE $Bytes ($offset + 6)
        $w = Read-U16LE $Bytes ($offset + 8)
        $h = Read-U16LE $Bytes ($offset + 10)
        $flags = Read-U16LE $Bytes ($offset + 12)
        $sequence = Read-U16LE $Bytes ($offset + 14)
        $group = Read-U16LE $Bytes ($offset + 16)

        if ($w -le 0 -or $h -le 0) {
            throw "Invalid resource dimensions at offset 0x$($offset.ToString('X')): ${w}x${h}"
        }

        $pixelBytes = $w * $h * 2
        $nextOffset = $offset + 28 + $pixelBytes
        if ($nextOffset -gt $Bytes.Length) {
            throw "Resource id $id at offset 0x$($offset.ToString('X')) exceeds file size."
        }

        $entries += [pscustomobject]@{
            Index = @($entries).Count
            Offset = $offset
            HeaderSize = 28
            Id = [UInt32]$id
            X = $x
            Y = $y
            Width = $w
            Height = $h
            Flags = $flags
            Sequence = $sequence
            Group = $group
            PixelOffset = $offset + 28
            PixelBytes = $pixelBytes
            NextOffset = $nextOffset
        }

        $offset = $nextOffset
    }

    if ($offset -ne $Bytes.Length) {
        throw "Parser stopped at 0x$($offset.ToString('X')), file length is 0x$($Bytes.Length.ToString('X'))."
    }

    return [pscustomobject]@{
        DeclaredCount = $declaredCount
        ParsedCount = @($entries).Count
        Entries = $entries
    }
}

function Convert-Rgb565ToRgb24([UInt16]$Value) {
    $r5 = ($Value -shr 11) -band 0x1f
    $g6 = ($Value -shr 5) -band 0x3f
    $b5 = $Value -band 0x1f
    $r = [byte][Math]::Round($r5 * 255 / 31)
    $g = [byte][Math]::Round($g6 * 255 / 63)
    $b = [byte][Math]::Round($b5 * 255 / 31)
    return @($r, $g, $b)
}

function Write-BmpFromRgb565([byte[]]$Bytes, [object]$Entry, [string]$Path) {
    $w = [int]$Entry.Width
    $h = [int]$Entry.Height
    $rowBytes = $w * 3
    $stride = (($rowBytes + 3) -band (-bnot 3))
    $imageSize = $stride * $h
    $fileSize = 54 + $imageSize

    $bmp = New-Object byte[] $fileSize
    $enc = [Text.Encoding]::ASCII
    [Array]::Copy($enc.GetBytes("BM"), 0, $bmp, 0, 2)
    Write-U32LE $bmp 2 ([UInt32]$fileSize)
    Write-U32LE $bmp 10 54
    Write-U32LE $bmp 14 40
    Write-U32LE $bmp 18 ([UInt32]$w)
    Write-U32LE $bmp 22 ([UInt32]$h)
    Write-U16LE $bmp 26 1
    Write-U16LE $bmp 28 24
    Write-U32LE $bmp 34 ([UInt32]$imageSize)

    for ($y = 0; $y -lt $h; $y++) {
        $srcY = $h - 1 - $y
        $dstRow = 54 + ($y * $stride)
        for ($x = 0; $x -lt $w; $x++) {
            $src = $Entry.PixelOffset + (($srcY * $w + $x) * 2)
            $v = ([int]$Bytes[$src]) -bor (([int]$Bytes[$src + 1]) -shl 8)
            $rgb = Convert-Rgb565ToRgb24 ([UInt16]$v)
            $dst = $dstRow + ($x * 3)
            $bmp[$dst] = $rgb[2]
            $bmp[$dst + 1] = $rgb[1]
            $bmp[$dst + 2] = $rgb[0]
        }
    }

    [IO.File]::WriteAllBytes($Path, $bmp)
}

function Select-Entries([object[]]$Entries) {
    $selected = $Entries
    if ($Ids -and $Ids.Count -gt 0) {
        $set = @{}
        foreach ($id in $Ids) { $set[[UInt32]$id] = $true }
        $selected = @($selected | Where-Object { $set.ContainsKey($_.Id) })
    }
    elseif ($FullScreenOnly) {
        $selected = @($selected | Where-Object { $_.Width -eq 128 -and $_.Height -eq 128 })
    }
    elseif (-not $All) {
        $selected = @($selected | Where-Object { $_.Id -ge 200 -and $_.Id -le 211 })
    }
    return @($selected)
}

$inputFullPath = (Resolve-Path -LiteralPath $InputPath).Path
$bytes = [IO.File]::ReadAllBytes($inputFullPath)
$parsed = Get-OledEntries $bytes
$entries = @($parsed.Entries)

switch ($Command) {
    "inspect" {
        [pscustomobject]@{
            File = $inputFullPath
            Length = $bytes.Length
            DeclaredCount = $parsed.DeclaredCount
            ParsedCount = $parsed.ParsedCount
            FirstResourceOffset = ("0x{0:X}" -f 0x15e)
        } | Format-List

        "Fullscreen 128x128 entries:"
        $entries |
            Where-Object { $_.Width -eq 128 -and $_.Height -eq 128 } |
            Select-Object Index, @{Name="Offset"; Expression={ "0x{0:X}" -f $_.Offset }}, Id, X, Y, Width, Height, Sequence, Group |
            Format-Table -AutoSize

        "Configured boot spinner entries 200-211:"
        $entries |
            Where-Object { $_.Id -ge 200 -and $_.Id -le 211 } |
            Select-Object Index, @{Name="Offset"; Expression={ "0x{0:X}" -f $_.Offset }}, Id, X, Y, Width, Height, Sequence, Group |
            Format-Table -AutoSize
    }

    "export" {
        New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
        $selected = Select-Entries $entries
        $manifest = @()

        foreach ($entry in $selected) {
            $base = "id_{0}_idx_{1}_{2}x{3}_xy_{4}_{5}" -f $entry.Id, $entry.Index, $entry.Width, $entry.Height, $entry.X, $entry.Y
            $bmpPath = Join-Path $OutDir ($base + ".bmp")
            Write-BmpFromRgb565 $bytes $entry $bmpPath
            $manifest += [pscustomobject]@{
                id = $entry.Id
                index = $entry.Index
                offset = ("0x{0:X}" -f $entry.Offset)
                x = $entry.X
                y = $entry.Y
                width = $entry.Width
                height = $entry.Height
                sequence = $entry.Sequence
                group = $entry.Group
                file = (Split-Path -Leaf $bmpPath)
            }
        }

        $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutDir "manifest.json") -Encoding UTF8
        "Exported $($selected.Count) entries to $OutDir"
    }

    "patch" {
        if (-not $OutputPath) { throw "patch requires -OutputPath" }
        if (-not $RawPath) { throw "patch requires -RawPath" }
        if (-not $Ids -or $Ids.Count -eq 0) { throw "patch requires -Ids" }

        $rawFullPath = (Resolve-Path -LiteralPath $RawPath).Path
        $raw = [IO.File]::ReadAllBytes($rawFullPath)
        $out = New-Object byte[] $bytes.Length
        [Array]::Copy($bytes, $out, $bytes.Length)

        $patched = @()
        foreach ($id in $Ids) {
            $matches = @($entries | Where-Object { $_.Id -eq [UInt32]$id })
            if ($matches.Count -ne 1) {
                throw "Expected exactly one resource with id $id, found $($matches.Count)."
            }
            $entry = $matches[0]
            if ($raw.Length -ne $entry.PixelBytes) {
                throw "Raw file length $($raw.Length) does not match resource id $id pixel length $($entry.PixelBytes) (${entry.Width}x${entry.Height}x2)."
            }
            [Array]::Copy($raw, 0, $out, $entry.PixelOffset, $raw.Length)
            $patched += $id
        }

        [IO.File]::WriteAllBytes($OutputPath, $out)
        "Patched ids $($patched -join ', ') into $OutputPath"
    }
}
