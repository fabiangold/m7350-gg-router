#!/bin/sh

HOSTS_FILE="/etc/hosts"
MARKER_START="# GG privacy block start"
MARKER_END="# GG privacy block end"
tmp="/tmp/hosts.ggunblock.$$"

sed "/$MARKER_START/,/$MARKER_END/d" "$HOSTS_FILE" > "$tmp"
cat "$tmp" > "$HOSTS_FILE"
rm -f "$tmp"

echo "TP-Link cloud/privacy host block removed."
