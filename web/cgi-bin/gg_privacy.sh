#!/bin/sh

. /WEBSERVER/www/cgi-bin/gg_common.sh
require_token
print_header

ACTION="$(get_param action)"

DOMAINS="
devs.tplinkcloud.com
n-devs.tplinkcloud.com
n-deventry.tplinkcloud.com
n-deventry-gw.tplinkcloud.com
n-devs-gw.tplinkcloud.com
download.tplinkcloud.com
"

write_hosts_without_block() {
  tmp="/tmp/hosts.gg.$$"
  sed "/$PRIVACY_MARKER_START/,/$PRIVACY_MARKER_END/d" "$HOSTS_FILE" > "$tmp"
  cat "$tmp" > "$HOSTS_FILE"
  rm -f "$tmp"
}

case "$ACTION" in
  block)
    write_hosts_without_block
    {
      echo "$PRIVACY_MARKER_START"
      for domain in $DOMAINS; do
        echo "0.0.0.0 $domain"
      done
      echo "$PRIVACY_MARKER_END"
    } >> "$HOSTS_FILE"
    echo "Privacy block enabled."
    ;;
  unblock)
    write_hosts_without_block
    echo "Privacy block disabled."
    ;;
  status)
    if grep -q "$PRIVACY_MARKER_START" "$HOSTS_FILE" 2>/dev/null; then
      echo "on"
    else
      echo "off"
    fi
    ;;
  *)
    echo "UNKNOWN_ACTION"
    ;;
esac
