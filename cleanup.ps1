# 1. Git index.lock entfernen (falls noch vorhanden)
$lockFile = "$PSScriptRoot\.git\index.lock"
if (Test-Path $lockFile) {
    Remove-Item -Force $lockFile
    Write-Host ".git/index.lock geloescht."
} else {
    Write-Host ".git/index.lock existiert nicht (bereits sauber)."
}

# 2. Doppelten export_fullscreen_backup/ Ordner loeschen (identisch mit export_fullscreen_current/, 472K)
$backupDir = "$PSScriptRoot\export_fullscreen_backup"
if (Test-Path $backupDir) {
    Remove-Item -Recurse -Force $backupDir
    Write-Host "export_fullscreen_backup geloescht."
} else {
    Write-Host "export_fullscreen_backup existiert nicht (bereits geloescht)."
}

# 3. Alle Aenderungen committen
Set-Location $PSScriptRoot
git add README.md deploy_gg_web.ps1 `
    scripts\block_tplink_cloud.sh scripts\gg_sd_backup.sh scripts\gg_watchdog.sh `
    scripts\lighttpd_gg_redirect.conf scripts\start_gg_web scripts\unblock_tplink_cloud.sh `
    web\cgi-bin\gg_common.sh web\cgi-bin\gg_sd.sh `
    web\gg\app.js web\gg\index.html
git commit -m "feat: SD live-tab, 3-layer cloud-block, CGI-gate, 403-auth, GG-SD backup

- index.html: SD-Tab komplett live (sdMountState, sdFreeDetail, sdBackupLastDetail, ...)
- app.js: 403-Behandlung, Token-Overlay, refreshSdStatus(), SD-Buttons
- gg_sd.sh: NEU - SD mount/umount/status/backup/list CGI
- gg_sd_backup.sh: Backup-Skript ohne Secrets (auth.txt/web_token/ovpn/key)
- gg_status.sh: sd_mounted/sd_free/sd_backup_last im Status-Output
- gg_watchdog.sh: SD-Mount (vfat/exfat/ext4), taegl. GG-SD Backup-Trigger
- gg_common.sh: require_token() sendet HTTP 403 mit Status-Header vor Content-type
- block_tplink_cloud.sh: 3-Schichten (hosts + 26 iptables IPs + kill)
- unblock_tplink_cloud.sh: synchronisiert, entfernt alle 26 iptables-Regeln
- lighttpd_gg_redirect.conf: / -> /gg/ Redirect + CGI-Gate (nur gg_* erlaubt)
- start_gg_web: gg_sd.sh in Bind-Mount-Liste aufgenommen
- deploy_gg_web.ps1: gg_sd_backup.sh und gg_sd.sh werden mitgedeployt
- Security-Audit: grep-Praezision (Leerzeichen-Anker), sd_last_backup Bugfix
- README: vollstaendig aktualisiert"

Write-Host "Commit fertig."
