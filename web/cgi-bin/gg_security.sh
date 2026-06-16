#!/bin/sh

. /WEBSERVER/www/cgi-bin/gg_common.sh
print_header
require_token

ACTION="$(get_param action)"
BACKUP_DIR="/usrdata/gg_backups"

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
  mkdir -p "$BACKUP_DIR"
  ts=$(date +%Y%m%d_%H%M%S)
  dest="$BACKUP_DIR/gg_backup_${ts}.tar.gz"
  cd "$VPN_DIR" && tar czf "$dest" auth.txt web_token current_profile current.ovpn profiles/ 2>/dev/null
  if [ -f "$dest" ]; then
    echo "backup=$dest"
  else
    echo "error=backup failed"
  fi
}

backup_list() {
  ls -1t "$BACKUP_DIR"/gg_backup_*.tar.gz 2>/dev/null | head -10 || echo "none"
}

backup_restore() {
  name="$(basename "$(get_param file)")"
  case "$name" in
    gg_backup_*.tar.gz)
      src="$BACKUP_DIR/$name"
      if [ ! -f "$src" ]; then
        echo "error=not found"
        return
      fi
      cd "$VPN_DIR" && tar xzf "$src" 2>/dev/null && \
        echo "ok=restored from $name" || echo "error=extract failed"
      ;;
    *)
      echo "error=invalid filename"
      ;;
  esac
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
  status)
    echo "telnet=$(netstat -lnt 2>/dev/null | grep -q ':23 ' && echo open || echo closed)"
    echo "upnp=$(netstat -lnu 2>/dev/null | grep -q ':1900 ' && echo open || echo closed)"
    echo "wps=$(netstat -lnt 2>/dev/null | grep -q ':52881 ' && echo open || echo closed)"
    echo "atfwd_block=$(iptables -S INPUT 2>/dev/null | grep -q -- '--dport 6609 -j DROP' && echo on || echo off)"
    ;;
  *)
    echo "UNKNOWN_ACTION"
    ;;
esac
