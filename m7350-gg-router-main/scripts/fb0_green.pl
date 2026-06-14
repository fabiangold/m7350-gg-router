#!/usr/bin/perl
use strict;
my $FB = '/dev/fb0';
open(my $fh, '<:raw', $FB) or die $!;
my $buf; read($fh, $buf, 32768); close($fh);

# fb0 ist Big-Endian RGB565: n* = network byte order (big-endian uint16)
my @px = unpack('n*', $buf);

for my $i (0..$#px) {
    my $v = $px[$i];
    my $r = ($v >> 11) & 0x1F;
    my $g = ($v >> 5)  & 0x3F;
    my $b =  $v        & 0x1F;
    if ($b > 10 && $b > $r && $b > ($g >> 1)) {
        my $lum = $b * 2; $lum = 63 if $lum > 63;
        $px[$i] = ($lum << 5) & 0x07E0;
    }
}

open(my $fw, '>:raw', $FB) or die $!;
print $fw pack('n*', @px);
close($fw);
print "OK\n";