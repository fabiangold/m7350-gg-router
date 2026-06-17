#!/bin/sh

. /WEBSERVER/www/cgi-bin/gg_common.sh
require_token
print_header

SD_MOUNT="/usrdata/sd"
GG_SD="$SD_MOUNT/GG-SD"
SD_BACKUP_SH="/usrdata/vpn/gg_sd_backup.sh"

ACTION="$(get_param action)"

sd_is_mounted() {
  grep -q " $SD_MOUNT " /proc/mounts 2>/dev/null
}

sd_free() {
  sd_is_mounted && \
    df -h "$SD_MOUNT" 2>/dev/null | sed -n '2p' | awk '{print $4}' || echo "--"
}

sd_total() {
  sd_is_mounted && \
    df -h "$SD_MOUNT" 2>/dev/null | sed -n '2p' | awk '{print $2}' || echo "--"
}

sd_fs() {
  grep " $SD_MOUNT " /proc/mounts 2>/dev/null | awk '{print $3}' | head -1 || echo "--"
}

sd_last_backup() {
  if [ -f "$GG_SD/gg_sd_backup.log" ]; then
    local ts
    ts="$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' \
      "$GG_SD/gg_sd_backup.log" 2>/dev/null | tail -1)"
    [ -n "$ts" ] && echo "$ts" && return
  fi
  echo "--"
}

try_mount() {
  mkdir -p "$SD_MOUNT"
  for fs in vfat exfat ext4 ntfs; do
    mount -t "$fs" /dev/mmcblk0p1 "$SD_MOUNT" 2>/dev/null && echo "$fs" && return 0
  done
  return 1
}

case "$ACTION" in
  status)
    if sd_is_mounted; then
      echo "sd_mounted=yes"
      echo "sd_free=$(sd_free)"
      echo "sd_total=$(sd_total)"
      echo "sd_fs=$(sd_fs)"
      echo "sd_backup_last=$(sd_last_backup)"
      echo "sd_files=$(find "$GG_SD" -type f 2>/dev/null | wc -l)"
    else
      echo "sd_mounted=no"
      echo "sd_free=--"
      echo "sd_total=--"
      echo "sd_fs=--"
      echo "sd_backup_last=--"
      echo "sd_files=--"
    fi
    ;;

  backup)
    if ! sd_is_mounted; then
      echo "error=SD-Karte nicht eingehaengt"
      exit 0
    fi
    if [ ! -x "$SD_BACKUP_SH" ]; then
      echo "error=gg_sd_backup.sh nicht gefunden oder nicht ausfuehrbar"
      exit 0
    fi
    "$SD_BACKUP_SH" 2>&1
    ;;

  list)
    if ! sd_is_mounted; then
      echo "SD-Karte nicht eingehaengt."
      exit 0
    fi
    if [ -d "$GG_SD" ]; then
      find "$GG_SD" -type f | sort | sed "s|$GG_SD/||"
    else
      echo "GG-SD Verzeichnis noch nicht erstellt. Bitte zuerst ein Backup starten."
    fi
    ;;

  mount)
    if sd_is_mounted; then
      echo "ok=SD-Karte bereits eingehaengt ($(sd_fs))"
      exit 0
    fi
    fs="$(try_mount)"
    if [ $? -eq 0 ]; then
      echo "ok=SD eingehaengt ($fs)"
    else
      echo "error=Kein erkanntes Dateisystem oder keine SD-Karte"
    fi
    ;;

  umount)
    if sd_is_mounted; then
      umount "$SD_MOUNT" 2>/dev/null && echo "ok=SD ausgehaengt" || echo "error=Aushängen fehlgeschlagen (Dateien in Benutzung?)"
    else
      echo "ok=SD-Karte war nicht eingehaengt"
    fi
    ;;

  *)
    echo "UNKNOWN_ACTION"
    ;;
esac
