#!/bin/sh

VPN_DIR="/usrdata/vpn"
TOKEN_FILE="$VPN_DIR/web_token"
HOSTS_FILE="/etc/hosts"
PRIVACY_MARKER_START="# GG privacy block start"
PRIVACY_MARKER_END="# GG privacy block end"

get_param() {
  echo "$QUERY_STRING" | tr '&' '\n' | sed -n "s/^$1=//p" | head -1
}

require_token() {
  if [ -f "$TOKEN_FILE" ]; then
    expected="$(cat "$TOKEN_FILE")"
    token="$(get_param token)"
    if [ -z "$token" ] || [ "$token" != "$expected" ]; then
      printf "Status: 403 Forbidden\r\nContent-type: text/plain\r\n\r\nFORBIDDEN\n"
      exit 0
    fi
  fi
}

print_header() {
  echo "Content-type: text/plain"
  echo ""
}

add_ttl_rule() {
  iptables -t mangle -C POSTROUTING -o rmnet+ -j TTL --ttl-set 65 2>/dev/null || \
    iptables -t mangle -A POSTROUTING -o rmnet+ -j TTL --ttl-set 65 2>/dev/null
}
