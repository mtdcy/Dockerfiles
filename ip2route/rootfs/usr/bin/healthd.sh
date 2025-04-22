#!/bin/bash -e
#
# options           = 
         REMOTE_HOST="${REMOTE_HOST:-}"
         SOCKS5_PORT="${SOCKS5_PORT:-}"
      DNS2SOCKS_PORT="${DNS2SOCKS_PORT:-}"
        DNSMASQ_PORT="${DNSMASQ_PORT:-}"
         REMOTE_ADDR="${REMOTE_ADDR:-}"

    HEALTHD_INTERVAL="${HEALTHD_INTERVAL:-60}"
        HEADTHD_HOST="${HEADTHD_HOST:-www.google.com}"

IFS='@:' read -r _ host _ <<< "$REMOTE_HOST"
[ -z "$host" ] || REMOTE_HOST="$host"

check() {
    echo -e "-- $(date)\\033[34m ⭐ $(tr -s ' ' <<< "$*") ⭐ \\033[0m"
    "$@"
}

while sleep "$HEALTHD_INTERVAL"; do
    # host check
    [ -z "$REMOTE_HOST"     ] || check ping -q -c3 "$REMOTE_HOST"
    # remote check
    [ -z "$REMOTE_ADDR"     ] || check traceroute -m 1 "$REMOTE_ADDR" | grep -Fw "$REMOTE_ADDR"
    # socks5 check
    [ -z "$SOCKS5_PORT"     ] || check curl --fail -sI -x "socks5h://127.0.0.1:$SOCKS5_PORT" "https://$HEADTHD_HOST"
    # dns2socks check
    [ -z "$DNS2SOCKS_PORT"  ] || check dig @127.0.0.1 -p "$DNS2SOCKS_PORT" "$HEADTHD_HOST"
    # dns check
    [ -z "$DNSMASQ_PORT"    ] || check dig -p "$DNSMASQ_PORT" "$HEADTHD_HOST"
done
