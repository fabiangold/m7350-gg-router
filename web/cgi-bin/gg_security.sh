#!/bin/sh

. /WEBSERVER/www/cgi-bin/gg_common.sh
print_header
require_token

ACTION="$(get_param action)"

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

case "$ACTION" in
  harden)
    apply_hardening
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
