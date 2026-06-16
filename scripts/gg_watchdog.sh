#!/bin/sh
VPN_DIR="/usrdata/vpn"
SURFSHARK_DNS1="162.252.172.57"
SURFSHARK_DNS2="149.154.159.92"
FALLBACK_DNS="1.1.1.1"
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
    flag="/proc/sys/net/ipv6/conf/$iface/disable_ipv6"
    [ -e "$flag" ] && echo 1 > "$flag" 2>/dev/null
  done
  ip6tables -P INPUT DROP 2>/dev/null
  ip6tables -P FORWARD DROP 2>/dev/null
  ip6tables -P OUTPUT DROP 2>/dev/null
}

kill_processes() {
  for proc in "$@"; do
    killall "$proc" 2>/dev/null
    pidof "$proc" 2>/dev/null | tr ' ' '\n' | while read pid; do
      [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null
    done
  done
}

ensure_daemon() {
  pattern="$1"
  shift
  pgrep -f "$pattern" >/dev/null 2>&1 && return
  setsid "$@" < /dev/null > /dev/null 2>&1 &
}

enforce_kill_switch
disable_ipv6

# SD-Karte einhaengen wenn vorhanden und noch nicht gemountet
SD_MOUNT="/usrdata/sd"
grep -q "$SD_MOUNT" /proc/mounts 2>/dev/null || \
  mount -t vfat /dev/mmcblk0p1 "$SD_MOUNT" 2>/dev/null

# TP-Link/unsichere Dienste beenden (starten sich ggf. neu)
kill_processes cloud_brd cloud_client atfwd_daemon upnpd wscd telnetd

# GG-Daemons am Leben halten. Das passiert hier statt direkt in Cron,
# damit pgrep nicht die Cron-Shell-Zeile selbst trifft.
[ -f /usrdata/vpn/fb0_daemon2.pl ] && ensure_daemon '[f]b0_daemon2' perl /usrdata/vpn/fb0_daemon2.pl
[ -f /usrdata/vpn/isp_daemon.pl ] && ensure_daemon '[i]sp_daemon.pl' perl /usrdata/vpn/isp_daemon.pl
[ -f /usrdata/vpn/gg_vpn_button.pl ] && ensure_daemon '[g]g_vpn_button' perl /usrdata/vpn/gg_vpn_button.pl

# WebUI nur vom LAN erreichbar, nicht vom Mobilfunknetz
iptables -C INPUT -i rmnet+ -p tcp --dport 80 -j DROP 2>/dev/null || \
  iptables -I INPUT 1 -i rmnet+ -p tcp --dport 80 -j DROP 2>/dev/null
iptables -C INPUT -i rmnet+ -p tcp --dport 443 -j DROP 2>/dev/null || \
  iptables -I INPUT 1 -i rmnet+ -p tcp --dport 443 -j DROP 2>/dev/null
iptables -C INPUT -i rmnet+ -p tcp --dport 8080 -j DROP 2>/dev/null || \
  iptables -I INPUT 1 -i rmnet+ -p tcp --dport 8080 -j DROP 2>/dev/null
iptables -C INPUT -i rmnet+ -p tcp --dport 5555 -j DROP 2>/dev/null || \
  iptables -I INPUT 1 -i rmnet+ -p tcp --dport 5555 -j DROP 2>/dev/null
iptables -C INPUT -i bridge0 -p tcp --dport 23 -j DROP 2>/dev/null || \
  iptables -I INPUT 1 -i bridge0 -p tcp --dport 23 -j DROP 2>/dev/null
iptables -C INPUT -i bridge0 -p tcp --dport 6609 -j DROP 2>/dev/null || \
  iptables -I INPUT 1 -i bridge0 -p tcp --dport 6609 -j DROP 2>/dev/null

# ISP-Name auf GGRouter halten (patcht volatile UCI nach jedem mobile-daemon Reset)
ISP_FILE="/var/volatile/tmp/.uci/isp_profile"
if [ -f "$ISP_FILE" ] && grep -q 'isp_name=O2' "$ISP_FILE" 2>/dev/null; then
  sed -i 's/isp_name=O2$/isp_name=GGRouter/' "$ISP_FILE"
  kill -TERM "$(ps | grep '/usr/bin/oledd' | grep -v grep | awk '{print $1}')" 2>/dev/null
fi

set_dns_dnat() {
  local target="$1"
  iptables -t nat -D PREROUTING -i bridge0 -p udp --dport 53 -j DNAT --to "$SURFSHARK_DNS1" 2>/dev/null
  iptables -t nat -D PREROUTING -i bridge0 -p tcp --dport 53 -j DNAT --to "$SURFSHARK_DNS1" 2>/dev/null
  iptables -t nat -D PREROUTING -i bridge0 -p udp --dport 53 -j DNAT --to "$FALLBACK_DNS" 2>/dev/null
  iptables -t nat -D PREROUTING -i bridge0 -p tcp --dport 53 -j DNAT --to "$FALLBACK_DNS" 2>/dev/null
  iptables -t nat -I PREROUTING 1 -i bridge0 -p udp --dport 53 -j DNAT --to "$target" 2>/dev/null
  iptables -t nat -I PREROUTING 1 -i bridge0 -p tcp --dport 53 -j DNAT --to "$target" 2>/dev/null
}

if [ -f "/tmp/gg_vpn_disabled" ]; then
  # VPN bewusst ausgeschaltet -> nicht neu starten, Kill-Switch bleibt (oben schon gesetzt).
  : > "$PIP_CACHE"
elif ! ip addr show tun0 >/dev/null 2>&1; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') tun0 down, restarting VPN" >> "$LOG"
  /etc/init.d/start_vpn restart >> "$LOG" 2>&1 &
  : > "$PIP_CACHE"
else
  # VPN laeuft: Surfshark-DNS sicherstellen (verhaelt sich wie DNAT-Ziel-Check)
  grep -q "$SURFSHARK_DNS1" /etc/resolv.conf 2>/dev/null || {
    echo "nameserver $SURFSHARK_DNS1" > /etc/resolv.conf
    echo "nameserver $SURFSHARK_DNS2" >> /etc/resolv.conf
    set_dns_dnat "$SURFSHARK_DNS1"
  }
  pip="$(wget -q -T 5 -O - http://ifconfig.me/ip 2>/dev/null)"
  [ -z "$pip" ] && pip="$(wget -q -T 5 -O - http://api.ipify.org 2>/dev/null)"
  [ -n "$pip" ] && echo "$pip" > "$PIP_CACHE"
fi
