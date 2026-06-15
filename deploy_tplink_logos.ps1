param(
    [string]$AdbPath = "adb",
    [switch]$ApplyOled,
    [switch]$SkipWeb,
    [switch]$SkipOled
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$assetScript = Join-Path $root "tools\create_gg_logo_assets.ps1"
$oledTool = Join-Path $root "tools\oled_res_tool.ps1"
$assets = Join-Path $root "assets"
$work = Join-Path $root "device_backup_logo_probe"

function Run-Adb {
    param([Parameter(ValueFromRemainingArguments = $true)][object[]]$AdbArgs)
    if ($AdbArgs.Count -eq 1 -and $AdbArgs[0] -is [array]) {
        $AdbArgs = @($AdbArgs[0])
    }
    $flatArgs = @($AdbArgs | ForEach-Object { [string]$_ })
    & $AdbPath @flatArgs
    if ($LASTEXITCODE -ne 0) {
        throw "adb failed: $AdbPath $($flatArgs -join ' ')"
    }
}

function Ensure-LogoAssets() {
    $required = @(
        "assets\web\logo_small.png",
        "assets\web\logo_big.png",
        "assets\web\phone\logo.png",
        "assets\web\favicon.png",
        "assets\web\app.png",
        "assets\web\phone\app.png",
        "assets\gg_logo_38x14.raw",
        "assets\gg_logo_81x30.raw"
    )
    $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $root $_)) })
    if ($missing.Count -gt 0) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $assetScript
        if ($LASTEXITCODE -ne 0) {
            throw "Logo asset generation failed."
        }
    }
}

function Set-HtmlBranding([string]$Path) {
    $html = Get-Content -Raw -LiteralPath $Path
    $html = [regex]::Replace(
        $html,
        'href="data:image/x-icon;base64,[^"]+"\s*type="image/x-icon"\s*rel="shortcut icon"',
        'href="images/logo_small.png" type="image/png" rel="shortcut icon"'
    )
    $html = $html -replace 'href="images/favicon\.png"\s+type="image/png"\s+rel="shortcut icon"', 'href="images/logo_small.png" type="image/png" rel="shortcut icon"'
    $html = $html -replace 'href="http://www\.tp-link\.com"\s+target="_blank"\s+id="logoWrapper"', 'href="/gg/" id="logoWrapper"'
    $html = $html -replace 'href="http://www\.tp-link\.com"', 'href="/gg/"'
    $html = $html -replace 'href="https://itunes\.apple\.com/[^"]+"', 'href="/gg/"'
    $html = $html -replace 'href="https://play\.google\.com/[^"]+"', 'href="/gg/"'
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path, $html, $utf8NoBom)
}

Ensure-LogoAssets

if (-not $SkipWeb) {
    Run-Adb @("shell", "mkdir -p /usrdata/www/images/phone /usrdata/www/root")
    Run-Adb @("push", (Join-Path $assets "web\logo_small.png"), "/usrdata/www/images/logo_small.png")
    Run-Adb @("push", (Join-Path $assets "web\logo_big.png"), "/usrdata/www/images/logo_big.png")
    Run-Adb @("push", (Join-Path $assets "web\phone\logo.png"), "/usrdata/www/images/phone/logo.png")
    Run-Adb @("push", (Join-Path $assets "web\favicon.png"), "/usrdata/www/images/favicon.png")
    Run-Adb @("push", (Join-Path $assets "web\app.png"), "/usrdata/www/images/app.png")
    Run-Adb @("push", (Join-Path $assets "web\phone\app.png"), "/usrdata/www/images/phone/app.png")

    $htmlWork = Join-Path $work "html_branding"
    New-Item -ItemType Directory -Force -Path $htmlWork | Out-Null
    foreach ($name in @("login.html", "phoneIndex.html")) {
        $localHtml = Join-Path $htmlWork $name
        Run-Adb @("pull", "/WEBSERVER/www/$name", $localHtml)
        Set-HtmlBranding $localHtml
        Run-Adb @("push", $localHtml, "/usrdata/www/root/$name")
    }

    Run-Adb @("push", (Join-Path $root "scripts\start_gg_web"), "/etc/init.d/start_gg_web")
    Run-Adb @("shell", "chmod +x /etc/init.d/start_gg_web && /etc/init.d/start_gg_web restart")
    Write-Host "Web TP-Link logos are bind-mounted from /usrdata/www/images."
}

if (-not $SkipOled) {
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    $current = Join-Path $work "oled_res_current"
    $step = Join-Path $work "oled_res_logo_2415"
    $patched = Join-Path $work "oled_res_logo_patched"

    Run-Adb @("pull", "/etc/oled_res", $current)

    & powershell -NoProfile -ExecutionPolicy Bypass -File $oledTool `
        -Command patch `
        -InputPath $current `
        -RawPath (Join-Path $assets "gg_logo_38x14.raw") `
        -OutputPath $step `
        -Ids 2415
    if ($LASTEXITCODE -ne 0) { throw "Patching OLED resource 2415 failed." }

    & powershell -NoProfile -ExecutionPolicy Bypass -File $oledTool `
        -Command patch `
        -InputPath $step `
        -RawPath (Join-Path $assets "gg_logo_81x30.raw") `
        -OutputPath $patched `
        -Ids 2416
    if ($LASTEXITCODE -ne 0) { throw "Patching OLED resource 2416 failed." }

    Write-Host "Prepared patched OLED resource: $patched"

    if ($ApplyOled) {
        Run-Adb @("shell", 'cp /etc/oled_res /usrdata/vpn/oled_res.before_gg_logo_$(date +%Y%m%d_%H%M%S)')
        Run-Adb @("push", $patched, "/tmp/oled_res_gg_logo")
        Run-Adb @("shell", "cp /tmp/oled_res_gg_logo /etc/oled_res && sync && killall oledd 2>/dev/null; /usr/bin/oledd &")
        Write-Host "OLED TP-Link logo resources 2415 and 2416 replaced. Backup is in /usrdata/vpn/."
    }
    else {
        Write-Host "Dry run only. Re-run with -ApplyOled to install the patched /etc/oled_res."
    }
}
