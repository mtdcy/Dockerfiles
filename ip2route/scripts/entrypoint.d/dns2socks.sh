#!/bin/bash
#
# options               =
          DNS2SOCKS_PORT="${DNS2SOCKS_PORT:-5353}"
        DNS2SOCKS_SERVER="${DNS2SOCKS_SERVER:-8.8.8.8}"
       DNS2SOCKS_LOGFILE="${DNS2SOCKS_LOGFILE:-/config/dns2socks.log}"

info() {
    echo -e "--\\033[32m $* \\033[0m"
}

echocmd() {
    echo -e "--\\033[34m $* \\033[0m"
    "$@"
}
        
IFS=":" read -r dns port <<< "$DNS2SOCKS_SERVER"

args=( --verbosity debug )
args+=( --dns-remote-server "$dns:${port:-53}" )
# socks settings
args+=( --socks5-settings "socks5://127.0.0.1:$SOCKS5_PORT" )
# bind to localhost
args+=( --listen-addr "127.0.0.1:$DNS2SOCKS_PORT" )
# both tcp & udp
args+=( --force-tcp )
# quick failure
args+=( --timeout 1 )

dns2socks=( /usr/bin/dns2socks "${args[@]}" )

info "🚀 ${dns2socks[*]} 🚀"
"${dns2socks[@]}" >> "$DNS2SOCKS_LOGFILE" 2>&1 & disown
