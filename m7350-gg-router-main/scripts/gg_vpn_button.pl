#!/usr/bin/perl
# GG Router - VPN-Toggle per Tastenkombination am Geraet
# Geste: Menue-Taste (event1, code 103) HALTEN + Power (event0, code 116) kurz tippen.
# Kollisionsfrei zum Normalbetrieb (Menue-Navigieren = einzelne Taps; Power-Wake = einzeln).
# Liest die Input-Devices nicht-exklusiv mit (key_detect grabbt sie nicht).
use POSIX;

my $DEV0 = "/dev/input/event0";   # power  (KEY_POWER 116)
my $DEV1 = "/dev/input/event1";   # menu   (KEY_UP   103)
my $VPN_DIR = "/usrdata/vpn";
my $OPENVPN = "$VPN_DIR/openvpn";
my $CONFIG  = "$VPN_DIR/current.ovpn";
my $LOG     = "$VPN_DIR/vpn.log";
my $PIDF    = "$VPN_DIR/openvpn.pid";
my $DISABLED = "/tmp/gg_vpn_disabled";   # Flag (volatil): VPN bewusst aus -> Watchdog laesst es in Ruhe; Reboot=wieder an
my $FB      = "/dev/fb0";

sub vpn_up {
    my $o = `ip addr show tun0 2>/dev/null`;
    return ($o =~ /inet /) ? 1 : 0;
}

# Kurzer Vollbild-Flash als sofortige Quittung (oledd zeichnet danach normal neu)
sub flash {
    my ($rgb565) = @_;
    open(my $fh, ">:raw", $FB) or return;
    print $fh pack("v", $rgb565) x 16384;   # 128*128 Pixel
    close $fh;
}

sub start_vpn {
    system("iptables -t mangle -C POSTROUTING -o rmnet+ -j TTL --ttl-set 65 2>/dev/null || " .
           "iptables -t mangle -A POSTROUTING -o rmnet+ -j TTL --ttl-set 65 2>/dev/null");
    if (open(my $p, "<", $PIDF)) { my $pid = <$p>; close $p; chomp $pid;
        if ($pid && kill(0, $pid)) { return; } }
    system("killall openvpn 2>/dev/null");
    system("$OPENVPN --config $CONFIG --daemon --writepid $PIDF --log $LOG");
}

sub stop_vpn {
    if (open(my $p, "<", $PIDF)) { my $pid = <$p>; close $p; chomp $pid;
        kill('TERM', $pid) if $pid; }
    system("killall openvpn 2>/dev/null");
    unlink $PIDF;
}

sub toggle {
    if (vpn_up()) {
        # Bewusst AUS: Flag setzen, damit der Watchdog nicht neu startet.
        # Kill-Switch bleibt scharf -> kein Internet, kein Leak (max. Privatsphaere).
        open(my $f, ">", $DISABLED) and close($f);
        stop_vpn();
        flash(0xF800);   # rot = VPN aus
    } else {
        unlink $DISABLED;   # Flag loeschen -> Watchdog darf wieder ueberwachen
        flash(0x07E0);   # gruen = VPN startet
        start_vpn();
    }
}

open(my $f0, "<:raw", $DEV0) or die "event0: $!";
open(my $f1, "<:raw", $DEV1) or die "event1: $!";
my $rin = '';
vec($rin, fileno($f0), 1) = 1;
vec($rin, fileno($f1), 1) = 1;

my $menu_down = 0;
my $last_toggle = 0;

while (1) {
    my $r = $rin;
    select($r, undef, undef, undef);

    if (vec($r, fileno($f1), 1)) {
        if (sysread($f1, my $b, 16) == 16) {
            my ($s,$u,$t,$c,$v) = unpack("l l S S l", $b);
            $menu_down = ($v != 0) if ($t == 1 && $c == 103);
        }
    }
    if (vec($r, fileno($f0), 1)) {
        if (sysread($f0, my $b, 16) == 16) {
            my ($s,$u,$t,$c,$v) = unpack("l l S S l", $b);
            if ($t == 1 && $c == 116 && $v == 1) {
                my $now = time();
                if ($menu_down && ($now - $last_toggle) > 3) {
                    $last_toggle = $now;
                    toggle();
                }
            }
        }
    }
}
