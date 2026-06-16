#!/bin/sh
VPN_DIR="/usrdata/vpn"
KEY_FILE="$VPN_DIR/backup.key"
SD_BACKUP_DIR="/usrdata/sd/gg_backups"
INT_BACKUP_DIR="/usrdata/gg_backups"
KEEP=30

# Schluessel einmalig generieren (32 Byte hex, 256 Bit)
if [ ! -f "$KEY_FILE" ]; then
  dd if=/dev/urandom bs=32 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n' > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
fi

if grep -q '/usrdata/sd' /proc/mounts 2>/dev/null; then
  BACKUP_DIR="$SD_BACKUP_DIR"
else
  BACKUP_DIR="$INT_BACKUP_DIR"
fi

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR" 2>/dev/null || true
ts=$(date +%Y%m%d_%H%M%S)
dest="$BACKUP_DIR/gg_backup_${ts}.tar.gz.enc"
cd "$VPN_DIR" && tar czf - auth.txt web_token current_profile current.ovpn profiles/ 2>/dev/null | \
  openssl enc -aes-256-cbc -kfile "$KEY_FILE" -md sha256 -out "$dest" 2>/dev/null

if [ -f "$dest" ] && [ -s "$dest" ]; then
  chmod 600 "$dest" 2>/dev/null || true
  echo "$(date '+%Y-%m-%d %H:%M:%S') daily backup (encrypted): $dest" >> "$VPN_DIR/watchdog.log"
  ls -1t "$BACKUP_DIR"/gg_backup_*.tar.gz.enc 2>/dev/null | tail -n +$((KEEP+1)) | while read f; do
    rm -f "$f"
  done
else
  rm -f "$dest" 2>/dev/null
  echo "$(date '+%Y-%m-%d %H:%M:%S') daily backup FAILED" >> "$VPN_DIR/watchdog.log"
fi
