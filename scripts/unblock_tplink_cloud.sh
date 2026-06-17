#!/bin/sh

HOSTS_FILE="/etc/hosts"
MARKER_START="# GG privacy block start"
MARKER_END="# GG privacy block end"

# Layer 1: /etc/hosts Block entfernen
tmp="/tmp/hosts.ggunblock.$$"
sed "/$MARKER_START/,/$MARKER_END/d" "$HOSTS_FILE" > "$tmp"
cat "$tmp" > "$HOSTS_FILE"
rm -f "$tmp"
echo "Layer 1: DNS-Block entfernt."

# Layer 2: iptables OUTPUT Regeln fuer TP-Link Cloud-IPs entfernen
TPLINK_IPS="
3.248.42.241 34.242.126.20 34.250.126.53 34.250.187.9
34.251.217.220 34.251.44.239 34.254.39.39 34.255.90.2
52.18.4.252 52.212.41.217 52.213.61.21 52.214.76.179
52.31.160.4 54.155.5.194 54.195.117.230 54.216.112.52
54.217.181.47 54.246.206.184 54.72.131.22 54.72.192.58
54.73.167.156 63.33.72.236 65.8.131.14 65.8.131.27
65.8.131.30 65.8.131.33
"
removed=0
for ip in $TPLINK_IPS; do
  if iptables -C OUTPUT -d "$ip" -j DROP 2>/dev/null; then
    iptables -D OUTPUT -d "$ip" -j DROP 2>/dev/null && removed=$((removed+1))
  fi
done
echo "Layer 2: $removed iptables-Regeln entfernt."

echo "TP-Link cloud/privacy block entfernt."
