#!/bin/sh

. /WEBSERVER/www/cgi-bin/gg_common.sh
print_header
require_token

vpn="DISCONNECTED"
ip addr show tun0 >/dev/null 2>&1 && vpn="CONNECTED"

profile="$(cat "$VPN_DIR/current_profile" 2>/dev/null)"
[ -z "$profile" ] && profile="unknown"
tun_ip="$(ip addr show tun0 2>/dev/null | sed -n 's/.*inet \([^ ]*\).*/\1/p' | head -1)"
wan_ip="$(ip addr show rmnet_data0 2>/dev/null | sed -n 's/.*inet \([^ ]*\).*/\1/p' | head -1)"
[ -z "$wan_ip" ] && wan_ip="$(ip addr show rmnet0 2>/dev/null | sed -n 's/.*inet \([^ ]*\).*/\1/p' | head -1)"

gateway="$(ip route 2>/dev/null | sed -n 's/^default via \([^ ]*\).*/\1/p' | head -1)"
uptime="$(cut -d. -f1 /proc/uptime 2>/dev/null)"
clients="$(ip -4 neigh show dev bridge0 2>/dev/null | grep 'lladdr' | grep -Ev 'FAILED|INCOMPLETE' | wc -l | tr -d ' ')"
if [ -z "$clients" ] || [ "$clients" = "0" ]; then
  clients="$(awk 'NR>1 && $3=="0x2" {c++} END {print c+0}' /proc/net/arp 2>/dev/null)"
fi
client_list="$(ip -4 neigh show dev bridge0 2>/dev/null | grep 'lladdr' | grep -Ev 'FAILED|INCOMPLETE' | awk 'BEGIN {sep=""} {printf "%s%s,%s,%s", sep, $1, $5, $6; sep="|"}')"
openvpn="stopped"
pidof openvpn >/dev/null 2>&1 && openvpn="running"
adb="off"
pidof adbd >/dev/null 2>&1 && adb="on"
privacy="off"
grep -q "$PRIVACY_MARKER_START" "$HOSTS_FILE" 2>/dev/null && privacy="on"
token_state="off"
[ -f "$TOKEN_FILE" ] && token_state="on"

df_free() {
  line="$(df -h "$1" 2>/dev/null | sed -n '2p')"
  set -- $line
  [ -n "$4" ] && echo "$3 used / $4 free"
}

usr_storage="$(df_free /usrdata)"
root_storage="$(df_free /)"
storage=""
[ -n "$usr_storage" ] && storage="usrdata: $usr_storage"
[ -n "$root_storage" ] && storage="${storage}; root: $root_storage"

ssid="$(uci -c /data/config get wlan.basic_setting.ssid 2>/dev/null)"
hidden_ssid="$(uci -c /data/config get wlan.basic_setting.hidden_ssid 2>/dev/null)"
show_passphrase="$(uci -c /data/config get wlan.basic_setting.show_passphrase_on_oled 2>/dev/null)"
wps_feature="$(uci -c /data/config get wlan.basic_setting.wps_feature 2>/dev/null)"
ap_isolate="$(uci -c /data/config get wlan.basic_setting.ap_isolate 2>/dev/null)"
encrypt_type="$(uci -c /data/config get wlan.basic_setting.encrypt_type 2>/dev/null)"
max_assoc_sta="$(uci -c /data/config get wlan.basic_setting.max_assoc_sta 2>/dev/null)"

telnet_port="closed"
netstat -lnt 2>/dev/null | grep -q ':23 ' && telnet_port="open"
upnp_port="closed"
if netstat -lnu 2>/dev/null | grep -q ':1900 ' || pidof upnpd >/dev/null 2>&1; then
  upnp_port="open"
fi
wps_port="closed"
netstat -lnt 2>/dev/null | grep -q ':52881 ' && wps_port="open"
atfwd_block="off"
iptables -S INPUT 2>/dev/null | grep -q -- '--dport 6609 -j DROP' && atfwd_block="on"

# Battery: echte Quelle ist UCI battery_mgr.power_level, nicht das leere /sys capacity
charging="0"
battery=""
batt_level="$(uci get battery.battery_mgr.power_level 2>/dev/null)"
batt_charging="$(uci get battery.battery_mgr.is_charging 2>/dev/null)"
[ "$batt_charging" = "1" ] && charging="1"
if [ -n "$batt_level" ]; then
  battery="${batt_level}%"
  [ "$charging" = "1" ] && battery="${battery} (charging)"
else
  cap="$(cat /sys/class/power_supply/battery/capacity 2>/dev/null)"
  [ -n "$cap" ] && battery="${cap}%"
fi

# net_mode: keine zuverlaessige Funkmodus-Quelle vorhanden -> echten WAN-Status zeigen
if ip addr show rmnet_data0 2>/dev/null | grep -q 'inet ' || \
   ip addr show rmnet0 2>/dev/null | grep -q 'inet '; then
  net_mode="Connected"
else
  net_mode="No WAN"
fi

# device: /etc/hostname ist der Chipsatz-Codename (mdm9607) -> Modellname zeigen
device="TP-Link M7350"

public_ip="$(cat /tmp/gg_public_ip 2>/dev/null | tr -d '[:space:]')"
[ -z "$public_ip" ] && public_ip="--"
echo "vpn=$vpn"
echo "profile=$profile"
echo "public_ip=$public_ip"
echo "tun_ip=${tun_ip:---}"
echo "wan_ip=${wan_ip:---}"
echo "gateway=${gateway:---}"
echo "clients=${clients:---}"
echo "client_list=${client_list:---}"
echo "uptime=${uptime:---}s"
echo "net_mode=$net_mode"
echo "battery=${battery:---}"
echo "charging=$charging"
echo "storage=${storage:---}"
echo "storage_usr=${usr_storage:---}"
echo "storage_root=${root_storage:---}"
echo "openvpn=$openvpn"
echo "adb=$adb"
echo "privacy=$privacy"
echo "token=$token_state"
echo "device=$device"
echo "ssid=${ssid:---}"
echo "hidden_ssid=${hidden_ssid:---}"
echo "show_passphrase=${show_passphrase:---}"
echo "wps_feature=${wps_feature:---}"
echo "ap_isolate=${ap_isolate:---}"
echo "encrypt_type=${encrypt_type:---}"
echo "max_assoc_sta=${max_assoc_sta:---}"
echo "telnet_port=$telnet_port"
echo "upnp_port=$upnp_port"
echo "wps_port=$wps_port"
echo "atfwd_block=$atfwd_block"
