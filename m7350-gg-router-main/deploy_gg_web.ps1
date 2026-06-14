param(
    [string]$Token = "",
    [switch]$SetToken
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

function Run-Adb([string[]]$Args) {
    & adb @Args
    if ($LASTEXITCODE -ne 0) {
        throw "adb failed: adb $($Args -join ' ')"
    }
}

# Zielverzeichnisse auf /usrdata (persistenter rw-Bereich)
Run-Adb @("shell", "mkdir -p /usrdata/www/gg /usrdata/www/cgi-bin /usrdata/vpn")

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
