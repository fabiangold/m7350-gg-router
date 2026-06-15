#!/bin/sh
FB="/dev/fb0"
VPN_ON="/usrdata/vpn/oled_vpn_on.raw"
VPN_OFF="/usrdata/vpn/oled_vpn_off.raw"

[ ! -e "$FB" ] && exit 0
[ ! -f "$VPN_ON" ] && exit 0

if [ "$1" != "--daemon" ]; then
    setsid "$0" --daemon &
    # Starte fb0-Gruen-Daemon (haelt den Datenverbrauchs-Kreis gruen)
    pkill -f fb0_daemon 2>/dev/null
    setsid perl /usrdata/vpn/fb0_daemon2.pl 2>/dev/null &
    # Starte ISP-Name-Daemon (haelt GGRouter-Name gegen mobile-Daemon)
    pkill -f isp_daemon 2>/dev/null
    setsid perl /usrdata/vpn/isp_daemon.pl 2>/dev/null &
    # Starte VPN-Toggle-Tasten-Daemon (Menue halten + Power tippen = VPN an/aus)
    pkill -f gg_vpn_button 2>/dev/null
    setsid perl /usrdata/vpn/gg_vpn_button.pl 2>/dev/null &
    exit 0
fi

write_fb() {
    dd if="$1" of="$FB" bs=32768 count=1 2>/dev/null
}

prev_state=""
while true; do
    if ip addr show tun0 >/dev/null 2>&1; then
        cur="on"
    else
        cur="off"
    fi
    if [ "$cur" != "$prev_state" ]; then
        if [ "$cur" = "on" ]; then
            write_fb "$VPN_ON"
        else
            [ -f "$VPN_OFF" ] && write_fb "$VPN_OFF"
        fi
        prev_state="$cur"
    fi
    sleep 5
done