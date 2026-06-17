#!/bin/sh
#
# gg_sd_backup.sh -- Sichert alle GG-Dateien auf die SD-Karte (/usrdata/sd/GG-SD/)
# Kein Deploy noetig: wird direkt auf dem Router ausgefuehrt (via ADB shell oder Watchdog).
# KEINE sensiblen Dateien (auth.txt, web_token, *.ovpn, *.key).
#

SD_MOUNT="/usrdata/sd"
BACKUP_DIR="$SD_MOUNT/GG-SD"
VPN_DIR="/usrdata/vpn"
LIGHTTPD_CONF="/usrdata/etc/lighttpd.conf"
WWW_DIR="/usrdata/www"
CGI_SRC="/WEBSERVER/www/cgi-bin"
LOG="$BACKUP_DIR/gg_sd_backup.log"

# --- Pruefe SD-Karte ---
if ! grep -q " $SD_MOUNT " /proc/mounts 2>/dev/null; then
  echo "FEHLER: SD-Karte nicht eingehaengt unter $SD_MOUNT"
  exit 1
fi

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

ts="$(date '+%Y-%m-%d %H:%M:%S')"
echo "=== GG-SD Backup $ts ===" | tee "$LOG"

# --- Hilfsfunktion: sicher kopieren ---
cp_safe() {
  src="$1"
  dst="$2"
  if [ -e "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    cp -p "$src" "$dst" 2>/dev/null && echo "  OK $src" || echo "  FEHLER $src"
  else
    echo "  FEHLT $src (uebersprungen)"
  fi
}

cp_dir() {
  src="$1"
  dst="$2"
  if [ -d "$src" ]; then
    mkdir -p "$dst"
    cp -rp "$src/." "$dst/" 2>/dev/null && echo "  OK $src/" || echo "  FEHLER $src/"
  else
    echo "  FEHLT $src/ (uebersprungen)"
  fi
}

# --- 1. VPN-Skripte (ohne Secrets) ---
echo "--- Scripts ---" | tee -a "$LOG"
for f in start_vpn_hardened gg_watchdog.sh gg_oled.sh fb0_green.sh \
          block_tplink_cloud.sh unblock_tplink_cloud.sh gg_sd_backup.sh; do
  cp_safe "$VPN_DIR/$f" "$BACKUP_DIR/scripts/$f" | tee -a "$LOG"
done

# --- 2. lighttpd Konfiguration ---
echo "--- lighttpd ---" | tee -a "$LOG"
cp_safe "$LIGHTTPD_CONF" "$BACKUP_DIR/etc/lighttpd.conf" | tee -a "$LOG"

# Extra: nur die GG-Redirect-Datei falls separat eingebunden
for f in lighttpd_gg_redirect.conf gg_redirect.conf; do
  cp_safe "/usrdata/etc/$f" "$BACKUP_DIR/etc/$f" | tee -a "$LOG"
done

# --- 3. CGI-Skripte (nur gg_*) ---
echo "--- CGI ---" | tee -a "$LOG"
for f in "$CGI_SRC"/gg_*.sh; do
  [ -f "$f" ] && cp_safe "$f" "$BACKUP_DIR/cgi-bin/$(basename "$f")" | tee -a "$LOG"
done

# --- 4. Web-Interface (usrdata/www, kein Rootfs) ---
echo "--- Web ---" | tee -a "$LOG"
cp_dir "$WWW_DIR" "$BACKUP_DIR/www" | tee -a "$LOG"

# --- 5. UCI WLAN-Snapshot ---
echo "--- UCI WLAN ---" | tee -a "$LOG"
if uci -c /data/config show wlan 2>/dev/null > "$BACKUP_DIR/uci_wlan.txt"; then
  echo "  OK uci wlan snapshot" | tee -a "$LOG"
else
  echo "  FEHLER uci wlan" | tee -a "$LOG"
fi

# --- 6. Manifest ---
echo "--- Manifest ---" | tee -a "$LOG"
{
  echo "GG-SD Backup Manifest"
  echo "Erstellt: $ts"
  echo "Router: $(cat /etc/hostname 2>/dev/null || echo TP-Link-M7350)"
  echo "Kernel: $(uname -r 2>/dev/null)"
  echo ""
  echo "Dateien:"
  find "$BACKUP_DIR" -type f ! -name "gg_sd_backup.log" | sort | sed "s|$BACKUP_DIR/||"
} > "$BACKUP_DIR/MANIFEST.txt"

echo "" | tee -a "$LOG"
echo "Backup abgeschlossen: $BACKUP_DIR" | tee -a "$LOG"
echo "$(find "$BACKUP_DIR" -type f | wc -l) Dateien gesichert." | tee -a "$LOG"
