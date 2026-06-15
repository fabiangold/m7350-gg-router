#!/bin/sh
# fb0_green.sh ? ersetzt blaue Pixel in /dev/fb0 durch Gr?n
# Nutzt hexdump + sed + printf (busybox-kompatibel)

FB=/dev/fb0
TMP=/tmp/fb0_g.raw

[ ! -e "$FB" ] && exit 0

patch_fb() {
    cp "$FB" "$TMP" 2>/dev/null || return
    
    # Lese als hex string, ersetze blaue 2-byte-Sequenzen, schreibe zur?ck
    # Busybox hexdump: jedes byte als 2-hex-chars, kein trennzeichen
    HEX=$(hexdump -v -e '1/1 "%02x"' "$TMP")
    
    # Blaue ? Gr?ne Ersetzungen (little-endian: lo byte first)
    HEX=$(echo "$HEX" | sed \
        -e 's/ff00/e007/g' \
        -e 's/9c00/8007/g' \
        -e 's/de00/e007/g' \
        -e 's/7b00/2007/g' \
        -e 's/b500/e005/g' \
        -e 's/f700/a006/g' \
        -e 's/5a00/c006/g' \
        -e 's/3a00/a006/g' \
        -e 's/ad00/e003/g' \
        -e 's/3200/a004/g' \
        -e 's/1900/4006/g' \
        -e 's/1100/4004/g' \
    )
    
    # Hex-String zur?ck in binary
    printf "%b" "$(echo "$HEX" | sed 's/../\\x&/g')" > "$TMP" 2>/dev/null
    cp "$TMP" "$FB" 2>/dev/null
}

# Einmal patchen, dann alle 3s wiederholen
while true; do
    patch_fb
    sleep 3
done