#!/bin/sh

. /WEBSERVER/www/cgi-bin/gg_common.sh
print_header
require_token

ACTION="$(get_param action)"
PROFILE="$(get_param profile)"
OPENVPN="$VPN_DIR/openvpn"
CONFIG="$VPN_DIR/current.ovpn"
LOG="$VPN_DIR/vpn.log"
PID="$VPN_DIR/openvpn.pid"
PROFILE_FILE="$VPN_DIR/current_profile"
PROFILE_DIR="$VPN_DIR/profiles"

start_vpn() {
  mkdir -p "$VPN_DIR"
  rm -f /tmp/gg_vpn_disabled
  add_ttl_rule
  if [ -f "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; then
    echo "VPN already running pid=$(cat "$PID")"
    return 0
  fi
  killall openvpn 2>/dev/null
  "$OPENVPN" --config "$CONFIG" --daemon --writepid "$PID" --log "$LOG"
  sleep 3
  echo "VPN starting"
  ip addr show tun0 2>/dev/null
}

stop_vpn() {
  : > /tmp/gg_vpn_disabled
  if [ -f "$PID" ]; then
    kill "$(cat "$PID")" 2>/dev/null
    rm -f "$PID"
  fi
  killall openvpn 2>/dev/null
  echo "VPN stopped"
}

current_profile() {
  cat "$PROFILE_FILE" 2>/dev/null || echo "unknown"
}

switch_profile() {
  case "$PROFILE" in
    udp|tcp)
      src="$PROFILE_DIR/surfshark_de_fra_$PROFILE.ovpn"
      if [ ! -f "$src" ]; then
        echo "Missing profile file: $src"
        return 1
      fi
      cp "$src" "$CONFIG"
      echo "$PROFILE" > "$PROFILE_FILE"
      chmod 644 "$CONFIG" "$PROFILE_FILE" 2>/dev/null
      stop_vpn >/dev/null
      sleep 2
      start_vpn
      echo "Profile switched to $PROFILE"
      ;;
    *)
      echo "UNKNOWN_PROFILE"
      return 1
      ;;
  esac
}

public_ip() {
  ip_text="$(wget -qO- -T 8 http://api.ipify.org 2>/dev/null)"
  [ -z "$ip_text" ] && ip_text="$(curl -fsS --max-time 8 http://api.ipify.org 2>/dev/null)"
  [ -z "$ip_text" ] && ip_text="unavailable"
  echo "$ip_text"
}

case "$ACTION" in
  start)
    start_vpn
    ;;
  stop)
    stop_vpn
    ;;
  restart)
    stop_vpn >/dev/null
    sleep 2
    start_vpn
    ;;
  status)
    if ip addr show tun0 >/dev/null 2>&1; then
      echo "CONNECTED"
      ip addr show tun0 | grep inet
    else
      echo "DISCONNECTED"
    fi
    echo "profile=$(current_profile)"
    ;;
  profile)
    current_profile
    ;;
  switch)
    switch_profile
    ;;
  ipcheck)
    public_ip
    ;;
  log)
    tail -60 "$LOG" 2>/dev/null || echo "No log found."
    ;;
  clearlog)
    : > "$LOG"
    echo "Log cleared."
    ;;
  *)
    echo "UNKNOWN_ACTION"
    ;;
esac
