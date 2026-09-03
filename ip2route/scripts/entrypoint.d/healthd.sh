#!/bin/bash -e
#
# options           =
         REMOTE_HOST="${REMOTE_HOST:-}"

         SOCKS5_PORT="${SOCKS5_PORT:-}"
      DNS2SOCKS_PORT="${DNS2SOCKS_PORT:-}"
        DNSMASQ_PORT="${DNSMASQ_PORT:-}"

            LOCAL_ADDR="${LOCAL_ADDR:-}"
          REMOTE_ADDR="${REMOTE_ADDR:-}"

            LOCAL_ADDR="${LOCAL_ADDR:-$LOCAL_ADDR}"
          REMOTE_ADDR="${REMOTE_ADDR:-$REMOTE_ADDR}"

    HEALTHD_INTERVAL="${HEALTHD_INTERVAL:-60}"
     HEALTHD_LOGFILE="${HEALTHD_LOGFILE:-/var/log/healthd.log}"
         TEST_DOMAIN="${TEST_DOMAIN:-www.google.com}"

exec > >(tee -a "$HEALTHD_LOGFILE") 2>&1

check() {
    echo -e "⭐\\033[33m healthd: $* \\033[0m⭐" >&2
    "$@" || {
        tail "$HEALTHD_LOGFILE"
        return 1
    }
}

set -eo pipefail

IFS='@:' read -r _ host _ <<< "${REMOTE_HOST#*//}"
[ -z "$host" ] || REMOTE_HOST="$host"
[ "$REMOTE_HOST" = "127.0.0.1" ] && unset -v REMOTE_HOST || true

while sleep "$HEALTHD_INTERVAL"; do
    # tun device check
    test -z "$LOCAL_ADDR"       || check ping -c 1 -q "${LOCAL_ADDR%/*}"
    # remote check
    test -z "$REMOTE_ADDR"      || check ping -c 3 -q "$REMOTE_ADDR"
    # host check
    test -z "$REMOTE_HOST"      || check ping -c 3 -q "$REMOTE_HOST"

    # connection checks
    check url -fsSI "https://$TEST_DOMAIN"
    # socks5 check
    test -z "$SOCKS5_PORT"      || check curl -fsSI -x "socks5h://127.0.0.1:$SOCKS5_PORT" "https://$TEST_DOMAIN"
    # dns2socks check
    test -z "$DNS2SOCKS_PORT"   || check dig @127.0.0.1 -p "$DNS2SOCKS_PORT" "$TEST_DOMAIN"
    # dns check
    test -z "$DNSMASQ_PORT"     || check dig @127.0.0.1 -p "$DNSMASQ_PORT" "$TEST_DOMAIN"
done
