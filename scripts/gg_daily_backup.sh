#!/bin/sh
VPN_DIR="/usrdata/vpn"
SD_BACKUP_DIR="/usrdata/sd/gg_backups"
INT_BACKUP_DIR="/usrdata/gg_backups"
KEEP=30

if grep -q '/usrdata/sd' /proc/mounts 2>/dev/null; then
  BACKUP_DIR="$SD_BACKUP_DIR"
else
  BACKUP_DIR="$INT_BACKUP_DIR"
fi

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR" 2>/dev/null || true
ts=$(date +%Y%m%d_%H%M%S)
dest="$BACKUP_DIR/gg_backup_${ts}.tar.gz"
cd "$VPN_DIR" && tar czf "$dest" auth.txt web_token current_profile current.ovpn profiles/ 2>/dev/null

if [ -f "$dest" ]; then
  chmod 600 "$dest" 2>/dev/null || true
  echo "$(date '+%Y-%m-%d %H:%M:%S') daily backup: $dest" >> "$VPN_DIR/watchdog.log"
  # Aelteste Backups loeschen, nur die letzten $KEEP behalten
  ls -1t "$BACKUP_DIR"/gg_backup_*.tar.gz 2>/dev/null | tail -n +$((KEEP+1)) | while read f; do
    rm -f "$f"
  done
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') daily backup FAILED" >> "$VPN_DIR/watchdog.log"
fi
