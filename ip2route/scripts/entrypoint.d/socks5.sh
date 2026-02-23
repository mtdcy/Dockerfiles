#!/bin/bash

# options           =
         SOCKS5_PORT="${SOCKS5_PORT:-1070}"
      SOCKS5_FORWARD="${SOCKS5_FORWARD:-}" # no default forward
      SOCKS5_LOGFILE="${SOCKS5_LOGFILE:-/var/log/socks.log}"

info() {
    echo -e "🚀\\033[32m $* \\033[0m🚀"
}

echocmd() {
    echo -e "--\\033[34m $* \\033[0m"
    "$@"
}

info "init socks5 server 0.0.0.0:$SOCKS5_PORT@$SOCKS5_FORWARD"

socks=( /usr/bin/gost "-L=socks5://:$SOCKS5_PORT" )

[ -z "$SOCKS5_FORWARD" ] || socks+=( "-F=$SOCKS5_FORWARD" )

echocmd "${socks[@]}" 2>&1 | tee -a "$SOCKS5_LOGFILE" & disown
