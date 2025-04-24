#!/bin/bash -e
#
# options           = 
         REMOTE_HOST="${REMOTE_HOST:-}"
         SOCKS5_PORT="${SOCKS5_PORT:-}"
        DNSMASQ_PORT="${DNSMASQ_PORT:-}"
         REMOTE_ADDR="${REMOTE_ADDR:-}"
      DNS2SOCKS_PORT="${DNS2SOCKS_PORT:-}"
    DNS2SOCKS_SERVER="${DNS2SOCKS_SERVER:-$REMOTE_ADDR}"

    HEALTHD_INTERVAL="${HEALTHD_INTERVAL:-60}"
        HEADTHD_HOST="${HEADTHD_HOST:-www.google.com}"

check() {
    echo -e "⭐\\033[33m $* \\033[0m⭐"
    "$@"
}

on_exit() {
    check exit
}
trap on_exit EXIT

set -eo pipefail
    
check date
check ps aux
check ss -tunlp

IFS='@:' read -r _ host _ <<< "$REMOTE_HOST"
[ -z "$host" ] || REMOTE_HOST="$host"

while sleep "$HEALTHD_INTERVAL"; do
    check date
    # tun device check
    [ -z "$LOCAL_ADDR"      ] || check ping -q -c1 "$LOCAL_ADDR"
    # host check
    [ -z "$REMOTE_HOST"     ] || check ping -q -c3 "$REMOTE_HOST"
    # remote check
    [ -z "$REMOTE_ADDR"     ] || check traceroute -m 1 "$DNS2SOCKS_SERVER"| tail -1 | grep -Fw "$REMOTE_ADDR"
    # socks5 check
    [ -z "$SOCKS5_PORT"     ] || check curl --fail -sI -x "socks5h://127.0.0.1:$SOCKS5_PORT" "https://$HEADTHD_HOST"
    # dns2socks check
    [ -z "$DNS2SOCKS_PORT"  ] || check dig @127.0.0.1 -p "$DNS2SOCKS_PORT" "$HEADTHD_HOST"
    # dns check
    [ -z "$DNSMASQ_PORT"    ] || check dig @127.0.0.1 -p "$DNSMASQ_PORT" "$HEADTHD_HOST"
done
