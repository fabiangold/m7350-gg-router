#!/bin/sh

. /WEBSERVER/www/cgi-bin/gg_common.sh
require_token
print_header

ACTION="$(get_param action)"
KEY_FILE="$VPN_DIR/backup.key"
SD_BACKUP_DIR="/usrdata/sd/gg_backups"
INT_BACKUP_DIR="/usrdata/gg_backups"
if grep -q '/usrdata/sd' /proc/mounts 2>/dev/null; then
  BACKUP_DIR="$SD_BACKUP_DIR"
else
  BACKUP_DIR="$INT_BACKUP_DIR"
fi

ensure_key() {
  if [ ! -f "$KEY_FILE" ]; then
    dd if=/dev/urandom bs=32 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n' > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
  fi
}

apply_hardening() {
  uci -c /data/config set wlan.basic_setting.show_passphrase_on_oled='0' 2>/dev/null
  uci -c /data/config set wlan.basic_setting.wps_feature='0' 2>/dev/null
  uci -c /data/config set wlan.basic_setting.ap_isolate='1' 2>/dev/null
  uci -c /data/config commit wlan 2>/dev/null

  chmod 700 "$VPN_DIR/openvpn" 2>/dev/null
  chmod 600 "$VPN_DIR/auth.txt" "$VPN_DIR/web_token" "$VPN_DIR/current.ovpn" "$VPN_DIR"/profiles/*.ovpn 2>/dev/null

  ps w 2>/dev/null | grep 'busybox telnetd' | grep -v grep | awk '{print $1}' | while read pid; do
    kill "$pid" 2>/dev/null
  done
  for proc in upnpd wscd; do
    killall "$proc" 2>/dev/null
    pidof "$proc" 2>/dev/null | tr ' ' '\n' | while read pid; do
      [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null
    done
  done

  iptables -C INPUT -i bridge0 -p tcp --dport 6609 -j DROP 2>/dev/null || \
    iptables -I INPUT 1 -i bridge0 -p tcp --dport 6609 -j DROP 2>/dev/null

  echo "Hardening applied."
}

gen_token() {
  new_token=$(dd if=/dev/urandom bs=16 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')
  echo "$new_token" > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE" 2>/dev/null
  echo "new_token=$new_token"
}

backup_create() {
  ensure_key
  mkdir -p "$BACKUP_DIR"
  chmod 700 "$BACKUP_DIR" 2>/dev/null || true
  ts=$(date +%Y%m%d_%H%M%S)
  dest="$BACKUP_DIR/gg_backup_${ts}.tar.gz.enc"
  cd "$VPN_DIR" && tar czf - auth.txt web_token current_profile current.ovpn profiles/ 2>/dev/null | \
    openssl enc -aes-256-cbc -kfile "$KEY_FILE" -md sha256 -out "$dest" 2>/dev/null
  if [ -f "$dest" ] && [ -s "$dest" ]; then
    chmod 600 "$dest" 2>/dev/null || true
    echo "backup=$dest"
  else
    rm -f "$dest" 2>/dev/null
    echo "error=backup failed"
  fi
}

backup_list() {
  ls -1t "$BACKUP_DIR"/gg_backup_*.tar.gz.enc 2>/dev/null | head -10 || echo "none"
}

backup_restore() {
  name="$(basename "$(get_param file)")"
  case "$name" in
    gg_backup_*.tar.gz.enc)
      src="$BACKUP_DIR/$name"
      if [ ! -f "$src" ]; then
        echo "error=not found"
        return
      fi
      if [ ! -f "$KEY_FILE" ]; then
        echo "error=backup.key fehlt"
        return
      fi
      openssl enc -d -aes-256-cbc -kfile "$KEY_FILE" -md sha256 -in "$src" 2>/dev/null | \
        tar xzf - -C "$VPN_DIR" 2>/dev/null && \
        echo "ok=restored from $name" || echo "error=decrypt or extract failed"
      ;;
    *)
      echo "error=invalid filename"
      ;;
  esac
}

backup_show_key() {
  if [ -f "$KEY_FILE" ]; then
    echo "key=$(cat "$KEY_FILE")"
  else
    ensure_key
    echo "key=$(cat "$KEY_FILE")"
  fi
}

case "$ACTION" in
  harden)
    apply_hardening
    ;;
  gentoken)
    gen_token
    ;;
  backup)
    backup_create
    ;;
  backup_list)
    backup_list
    ;;
  backup_restore)
    backup_restore
    ;;
  backup_key)
    backup_show_key
    ;;
  status)
    echo "telnet=$(netstat -lnt 2>/dev/null | grep -q ':23 ' && echo open || echo closed)"
    if netstat -lnu 2>/dev/null | grep -q ':1900 ' || pidof upnpd >/dev/null 2>&1; then
      echo "upnp=open"
    else
      echo "upnp=closed"
    fi
    echo "wps=$(netstat -lnt 2>/dev/null | grep -q ':52881 ' && echo open || echo closed)"
    echo "atfwd_block=$(iptables -S INPUT 2>/dev/null | grep -q -- '--dport 6609 -j DROP' && echo on || echo off)"
    ;;
  *)
    echo "UNKNOWN_ACTION"
    ;;
esac
