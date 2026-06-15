#!/bin/sh
VPN_DIR="/usrdata/vpn"
LOG="$VPN_DIR/watchdog.log"
VPN_LOG="$VPN_DIR/vpn.log"
PIP_CACHE="/tmp/gg_public_ip"
MAX_LOG=51200
MAX_VPN_LOG=1048576

rotate_log() {
  [ -f "$1" ] && [ "$(wc -c < "$1" 2>/dev/null)" -gt "$2" ] && \
    mv "$1" "${1}.1" && : > "$1"
}

rotate_log "$LOG" "$MAX_LOG"
rotate_log "$VPN_LOG" "$MAX_VPN_LOG"

# Kill-Switch IMMER erzwingen (TP-Link netManager loescht ihn nach iptables-Reset).
# Strategie: als erste Regel in FORWARD einfuegen, sodass bridge0->rmnet+ immer geblockt ist.
# Beim VPN-An laeuft Traffic ueber tun0 (MASQUERADE), nicht direkt ueber rmnet+.
enforce_kill_switch() {
  iptables -C FORWARD -i bridge0 -o rmnet+ -j DROP 2>/dev/null || \
    iptables -I FORWARD 1 -i bridge0 -o rmnet+ -j DROP 2>/dev/null
}

disable_ipv6() {
  for iface in all default rmnet_data0 rmnet_data1 rmnet_data2 bridge0 wlan0; do
    echo 1 > /proc/sys/net/ipv6/conf/$iface/disable_ipv6 2>/dev/null
  done
  ip6tables -P INPUT DROP 2>/dev/null
  ip6tables -P FORWARD DROP 2>/dev/null
  ip6tables -P OUTPUT DROP 2>/dev/null
}

enforce_kill_switch
disable_ipv6

# TP-Link Cloud Prozesse beenden (starten sich ggf. neu)
for proc in cloud_brd cloud_client atfwd_daemon; do
  pidof "$proc" >/dev/null 2>&1 && kill -9 $(pidof "$proc") 2>/dev/null
done

# WebUI nur vom LAN erreichbar, nicht vom Mobilfunknetz
iptables -C INPUT -i rmnet+ -p tcp --dport 80 -j DROP 2>/dev/null || \
  iptables -I INPUT 1 -i rmnet+ -p tcp --dport 80 -j DROP 2>/dev/null
iptables -C INPUT -i rmnet+ -p tcp --dport 443 -j DROP 2>/dev/null || \
  iptables -I INPUT 1 -i rmnet+ -p tcp --dport 443 -j DROP 2>/dev/null
iptables -C INPUT -i rmnet+ -p tcp --dport 8080 -j DROP 2>/dev/null || \
  iptables -I INPUT 1 -i rmnet+ -p tcp --dport 8080 -j DROP 2>/dev/null

# ISP-Name auf GGRouter halten (patcht volatile UCI nach jedem mobile-daemon Reset)
ISP_FILE="/var/volatile/tmp/.uci/isp_profile"
if [ -f "$ISP_FILE" ] && grep -q 'isp_name=O2' "$ISP_FILE" 2>/dev/null; then
  sed -i 's/isp_name=O2$/isp_name=GGRouter/' "$ISP_FILE"
  kill -TERM "$(ps | grep '/usr/bin/oledd' | grep -v grep | awk '{print $1}')" 2>/dev/null
fi

if [ -f "/tmp/gg_vpn_disabled" ]; then
  # VPN bewusst ausgeschaltet -> nicht neu starten, Kill-Switch bleibt (oben schon gesetzt).
  : > "$PIP_CACHE"
elif ! ip addr show tun0 >/dev/null 2>&1; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') tun0 down, restarting VPN" >> "$LOG"
  /etc/init.d/start_vpn restart >> "$LOG" 2>&1 &
  : > "$PIP_CACHE"
else
  grep -q '1.1.1.1' /etc/resolv.conf 2>/dev/null || {
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
    echo "nameserver 8.8.8.8" >> /etc/resolv.conf
  }
  pip="$(wget -q -T 5 -O - http://ifconfig.me/ip 2>/dev/null)"
  [ -z "$pip" ] && pip="$(wget -q -T 5 -O - http://api.ipify.org 2>/dev/null)"
  [ -n "$pip" ] && echo "$pip" > "$PIP_CACHE"
fi
