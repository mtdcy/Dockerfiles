#!/bin/bash -e
#
# options           = 
         REMOTE_HOST="${REMOTE_HOST:-}"

         SOCKS5_PORT="${SOCKS5_PORT:-}"
      DNS2SOCKS_PORT="${DNS2SOCKS_PORT:-}"
        DNSMASQ_PORT="${DNSMASQ_PORT:-}"

            SSH_ADDR="${SSH_ADDR:-}"
          SSH_REMOTE="${SSH_REMOTE:-}"

            N2N_ADDR="${N2N_ADDR:-$SSH_ADDR}"
          N2N_REMOTE="${N2N_REMOTE:-$SSH_REMOTE}"

    HEALTHD_INTERVAL="${HEALTHD_INTERVAL:-60}"
         TEST_DOMAIN="${TEST_DOMAIN:-www.google.com}"

check() {
    echo -e "⭐\\033[33m healthd: $* \\033[0m⭐" >&2
    "$@"
}

on_exit() {
    check exit
}
trap on_exit EXIT

set -eo pipefail
    
check ps aux

IFS='@:' read -r _ host _ <<< "${REMOTE_HOST#*//}"
[ -z "$host" ] || REMOTE_HOST="$host"
[ "$REMOTE_HOST" = "127.0.0.1" ] && unset -v REMOTE_HOST || true

while sleep "$HEALTHD_INTERVAL"; do
    check date
    # tun device check
    [ -z "$SSH_ADDR"        ] || check ping -c 1 -q "${SSH_ADDR%/*}"
    [ -z "$N2N_ADDR"        ] || check ping -c 1 -q "${N2N_ADDR%/*}"
    # remote check
    [ -z "$SSH_REMOTE"      ] || check ping -c 3 -q "$SSH_REMOTE"
    [ -z "$N2N_REMOTE"      ] || check ping -c 3 -q "$N2N_REMOTE"
    # host check
    [ -z "$REMOTE_HOST"     ] || check ping -c 3 -q "$REMOTE_HOST"
    # socks5 check
    [ -z "$SOCKS5_PORT"     ] || check curl --fail -I -x "socks5h://127.0.0.1:$SOCKS5_PORT" "https://$TEST_DOMAIN"
    # dns2socks check
    [ -z "$DNS2SOCKS_PORT"  ] || check dig @127.0.0.1 -p "$DNS2SOCKS_PORT" "$TEST_DOMAIN"
    # dns check
    [ -z "$DNSMASQ_PORT"    ] || check dig @127.0.0.1 -p "$DNSMASQ_PORT" "$TEST_DOMAIN"
done
