param(
    [string]$Token = "",
    [switch]$SetToken,
    [string]$AdbPath = "adb"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$webRoot = Join-Path $root "web"
$initScript     = Join-Path $root "scripts\start_gg_web"
$vpnScript      = Join-Path $root "scripts\vpn_hardened.sh"
$watchdogScript = Join-Path $root "scripts\gg_watchdog.sh"
$oledScript     = Join-Path $root "scripts\gg_oled.sh"
$oledOnRaw      = Join-Path $root "assets\oled_vpn_on.raw"
$oledOffRaw     = Join-Path $root "assets\oled_vpn_off.raw"
$logoSmall      = Join-Path $root "assets\web\logo_small.png"
$logoBig        = Join-Path $root "assets\web\logo_big.png"
$logoPhone      = Join-Path $root "assets\web\phone\logo.png"
$favicon        = Join-Path $root "assets\web\favicon.png"
$appImage       = Join-Path $root "assets\web\app.png"
$phoneAppImage  = Join-Path $root "assets\web\phone\app.png"

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

# Zielverzeichnisse auf /usrdata (persistenter rw-Bereich)
Run-Adb @("shell", "mkdir -p /usrdata/www/gg /usrdata/www/cgi-bin /usrdata/www/images/phone /usrdata/vpn")

# Web UI nach /usrdata pushen
Run-Adb @("push", (Join-Path $webRoot "gg\index.html"), "/usrdata/www/gg/index.html")
Run-Adb @("push", (Join-Path $webRoot "gg\style.css"),  "/usrdata/www/gg/style.css")
Run-Adb @("push", (Join-Path $webRoot "gg\app.js"),     "/usrdata/www/gg/app.js")

# CGI-Scripts nach /usrdata pushen
Run-Adb @("push", (Join-Path $webRoot "cgi-bin\gg_common.sh"),   "/usrdata/www/cgi-bin/gg_common.sh")
Run-Adb @("push", (Join-Path $webRoot "cgi-bin\gg_status.sh"),   "/usrdata/www/cgi-bin/gg_status.sh")
Run-Adb @("push", (Join-Path $webRoot "cgi-bin\gg_vpn.sh"),      "/usrdata/www/cgi-bin/gg_vpn.sh")
Run-Adb @("push", (Join-Path $webRoot "cgi-bin\gg_privacy.sh"),  "/usrdata/www/cgi-bin/gg_privacy.sh")
if (Test-Path (Join-Path $webRoot "cgi-bin\gg_security.sh")) {
    Run-Adb @("push", (Join-Path $webRoot "cgi-bin\gg_security.sh"), "/usrdata/www/cgi-bin/gg_security.sh")
}
Run-Adb @("shell", "chmod +x /usrdata/www/cgi-bin/gg_*.sh")

# Init-Script deployen und Symlink setzen (einmalig noetig)
if (Test-Path $initScript) {
    Run-Adb @("push", $initScript, "/etc/init.d/start_gg_web")
    Run-Adb @("shell", "chmod +x /etc/init.d/start_gg_web")
    Run-Adb @("shell", "ln -sf /etc/init.d/start_gg_web /etc/rc5.d/S87gg_web 2>/dev/null || true")
}

# VPN-Script + Watchdog deployen
if (Test-Path $vpnScript) {
    Run-Adb @("push", $vpnScript, "/etc/init.d/start_vpn")
    Run-Adb @("shell", "chmod +x /etc/init.d/start_vpn")
    Run-Adb @("shell", "ln -sf /etc/init.d/start_vpn /etc/rc5.d/S89start_vpn 2>/dev/null || true")
}
if (Test-Path $watchdogScript) {
    Run-Adb @("push", $watchdogScript, "/usrdata/vpn/gg_watchdog.sh")
    Run-Adb @("shell", "chmod +x /usrdata/vpn/gg_watchdog.sh")
    Run-Adb @("shell", "mkdir -p /etc/cron/crontabs")
    Run-Adb @("shell", "echo '*/2 * * * * /usrdata/vpn/gg_watchdog.sh' > /etc/cron/crontabs/root")
    Run-Adb @("shell", "ln -sf /etc/init.d/busybox-cron /etc/rc5.d/S90gg_cron 2>/dev/null || true")
    Run-Adb @("shell", "crond -c /etc/cron/crontabs -b 2>/dev/null || true")
}

# OLED daemon + status images
if (Test-Path $oledScript) {
    Run-Adb @("push", $oledScript, "/usrdata/vpn/gg_oled.sh")
    Run-Adb @("shell", "chmod +x /usrdata/vpn/gg_oled.sh")
}
if (Test-Path $oledOnRaw) {
    Run-Adb @("push", $oledOnRaw,  "/usrdata/vpn/oled_vpn_on.raw")
}
if (Test-Path $oledOffRaw) {
    Run-Adb @("push", $oledOffRaw, "/usrdata/vpn/oled_vpn_off.raw")
}

# Optionale Branding-Overrides fuer die originale TP-Link-Weboberflaeche.
if (Test-Path $logoSmall) {
    Run-Adb @("push", $logoSmall, "/usrdata/www/images/logo_small.png")
}
if (Test-Path $logoBig) {
    Run-Adb @("push", $logoBig, "/usrdata/www/images/logo_big.png")
}
if (Test-Path $logoPhone) {
    Run-Adb @("push", $logoPhone, "/usrdata/www/images/phone/logo.png")
}
if (Test-Path $favicon) {
    Run-Adb @("push", $favicon, "/usrdata/www/images/favicon.png")
}
if (Test-Path $appImage) {
    Run-Adb @("push", $appImage, "/usrdata/www/images/app.png")
}
if (Test-Path $phoneAppImage) {
    Run-Adb @("push", $phoneAppImage, "/usrdata/www/images/phone/app.png")
}

# Bind-Mounts sofort aktivieren (ohne Neustart)
Run-Adb @("shell", "/etc/init.d/start_gg_web restart")

if ($SetToken) {
    if (-not $Token) {
        throw "-SetToken requires -Token"
    }
    Run-Adb @("shell", "echo '$Token' > /usrdata/vpn/web_token")
    Write-Host "Token installed."
}

Write-Host "GG Web UI deployed: http://192.168.0.1/gg/"
