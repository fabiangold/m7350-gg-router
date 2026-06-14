#!/bin/sh

HOSTS_FILE="/etc/hosts"
MARKER_START="# GG privacy block start"
MARKER_END="# GG privacy block end"

DOMAINS="
devs.tplinkcloud.com
n-devs.tplinkcloud.com
n-deventry.tplinkcloud.com
n-deventry-gw.tplinkcloud.com
n-devs-gw.tplinkcloud.com
download.tplinkcloud.com
"

tmp="/tmp/hosts.ggblock.$$"

sed "/$MARKER_START/,/$MARKER_END/d" "$HOSTS_FILE" > "$tmp"
{
  echo "$MARKER_START"
  for domain in $DOMAINS; do
    echo "0.0.0.0 $domain"
  done
  echo "$MARKER_END"
} >> "$tmp"

cat "$tmp" > "$HOSTS_FILE"
rm -f "$tmp"

echo "TP-Link cloud/privacy host block installed."
