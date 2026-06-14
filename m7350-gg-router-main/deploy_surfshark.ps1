param(
    [ValidateSet("udp", "tcp")]
    [string]$Profile = "udp",
    [switch]$Restart
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$profilePath = Join-Path $root "local_vpn_profiles\surfshark_de_fra_$Profile.ovpn"
$authPath = Join-Path $root "local_vpn_profiles\surfshark_auth.txt"

if (-not (Test-Path -LiteralPath $profilePath)) {
    throw "Missing profile: $profilePath"
}
if (-not (Test-Path -LiteralPath $authPath)) {
    throw "Missing auth file: $authPath"
}

& adb shell "mkdir -p /usrdata/vpn"
if ($LASTEXITCODE -ne 0) { throw "adb shell mkdir failed" }

& adb push $profilePath /usrdata/vpn/current.ovpn
if ($LASTEXITCODE -ne 0) { throw "adb push current.ovpn failed" }

& adb push $authPath /usrdata/vpn/auth.txt
if ($LASTEXITCODE -ne 0) { throw "adb push auth.txt failed" }

& adb shell "chmod 600 /usrdata/vpn/auth.txt 2>/dev/null; chmod 644 /usrdata/vpn/current.ovpn"
if ($LASTEXITCODE -ne 0) { throw "adb chmod failed" }

Write-Host "Surfshark $Profile deployed to /usrdata/vpn/current.ovpn"

if ($Restart) {
    & adb shell "/etc/init.d/start_vpn restart"
    if ($LASTEXITCODE -ne 0) { throw "VPN restart failed" }
}
