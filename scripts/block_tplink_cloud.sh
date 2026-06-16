#!/bin/sh

HOSTS_FILE="/etc/hosts"
MARKER_START="# GG privacy block start"
MARKER_END="# GG privacy block end"

# Layer 1: DNS-Sperrliste (alle bekannten TP-Link Cloud-Domains)
DOMAINS="
devs.tplinkcloud.com
n-devs.tplinkcloud.com
n-deventry.tplinkcloud.com
n-deventry-gw.tplinkcloud.com
n-devs-gw.tplinkcloud.com
n-deventry-gw.tplinkcloud.com
download.tplinkcloud.com
deventry.tplinkcloud.com
aps.tplinkcloud.com
"

# Layer 2: Bekannte TP-Link Cloud-IPs (AWS eu-west-1 / us-east-1)
TPLINK_IPS="
3.248.42.241 34.242.126.20 34.250.126.53 34.250.187.9
34.251.217.220 34.251.44.239 34.254.39.39 34.255.90.2
52.18.4.252 52.212.41.217 52.213.61.21 52.214.76.179
52.31.160.4 54.155.5.194 54.195.117.230 54.216.112.52
54.217.181.47 54.246.206.184 54.72.131.22 54.72.192.58
54.73.167.156 63.33.72.236 65.8.131.14 65.8.131.27
65.8.131.30 65.8.131.33
"

# --- Layer 1: /etc/hosts ---
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

echo "Layer 1: DNS-Block installiert."

# --- Layer 2: iptables OUTPUT ---
for ip in $TPLINK_IPS; do
  iptables -C OUTPUT -d "$ip" -j DROP 2>/dev/null || \
    iptables -A OUTPUT -d "$ip" -j DROP 2>/dev/null
done

echo "Layer 2: iptables OUTPUT-Block installiert ($(echo $TPLINK_IPS | wc -w) IPs)."

# --- Layer 3: TP-Link Cloud-Prozesse beenden ---
for proc in cloud_brd cloud_client atfwd_daemon; do
  if pidof "$proc" >/dev/null 2>&1; then
    killall "$proc" 2>/dev/null
    echo "Layer 3: $proc beendet."
  fi
done

echo "TP-Link cloud/privacy block vollstaendig aktiv (3 Layer)."
