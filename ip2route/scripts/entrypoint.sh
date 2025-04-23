#!/bin/bash -e

#       options         =
export              MODE="${MODE:-basic}" # basic,route,serve
export       SOCKS5_PORT="${SOCKS5_PORT:-1070}"

export       REMOTE_HOST="${REMOTE_HOST:-}" # no def value
export        LOCAL_ADDR="${LOCAL_ADDR:-10.20.30.40}"
export       REMOTE_ADDR="${REMOTE_ADDR:-${LOCAL_ADDR%.*}.1}"
export         LOCAL_TUN="${LOCAL_TUN:-0}"
export        REMOTE_TUN="${REMOTE_TUN:-0}"
export           MAX_TUN="${MAX_TUN:-1}" # serve mode

export          SSH_OPTS="${SSH_OPTS:-}"

export DNSMASQ_INTERFACE="${DNSMASQ_INTERFACE:-}" # no def value
export    DNSMASQ_SERVER="${DNSMASQ_SERVER:-114.114.114.114}" # upstream dns server
export     DNSMASQ_IPSET="${DNSMASQ_IPSET:-/config/dnsmasq.ipset}"
export      DNSMASQ_PORT="${DNSMASQ_PORT:-53}"

export  DNS2SOCKS_SERVER="${DNS2SOCKS_SERVER:-$REMOTE_ADDR}"
export    DNS2SOCKS_PORT="${DNS2SOCKS_PORT:-1053}"

export    IP2ROUTE_TABLE="${IP2ROUTE_TABLE:-1}"
export     IP2ROUTE_FILE="${IP2ROUTE_FILE:-/config/data/default.lst}"

# Notes:
#
# - DNSMASQ_SERVER: it's for normal dns resolve, ip route get should return default.

info () {
    echo -e "🐳 [$(date '+%Y/%m/%d %H:%M:%S')]\\033[33m $* \\033[0m" >&2
}

echocmd() {
    echo -e "--\\033[34m $* \\033[0m"
    eval -- "$*"
}

cleanup() {
    info "*** cleanup ***"

    # cleanup explicitly
    /entrypoint.d/sshtunnel.sh cleanup || true
    /entrypoint.d/ip2route.sh cleanup || true

    pkill -INT  ssh || true
    pkill -INT  dns2socks || true
    pkill -USR1 dnsmasq || true

    sleep 1
}

if [ -z "$*" ]; then
    trap cleanup EXIT

    # sanity check
    [ "$MODE" = basic ] && unset LOCAL_ADDR || true
    [ "$MODE" = route ] || unset REMOTE_ADDR
    [ "$MODE" = serve ] && REMOTE_HOST= || MAX_TUN=1

    export LOCAL_ADDR REMOTE_ADDR MAX_TUN REMOTE_HOST

    # mount ~/.ssh to /config/ssh => multiple id files exists
    SSH_IDENT="${SSH_IDENT:-/config/ssh/id_ed25519}" # perfer ed25519
    [ -f "$SSH_IDENT" ] || SSH_IDENT="/config/ssh/id_rsa"
    [ -f "$SSH_IDENT" ] || SSH_IDENT="/config/ssh/id_ed25519"

    export SSH_IDENT
    export SSH_LOGFILE=/config/sshtunnel.log

    if [ -n "$REMOTE_HOST" ] || [ "$MODE" = serve ]; then
        info "*** init ssh tunnel ***"

        # socks5 server and ssh tunnel
        echocmd /entrypoint.d/sshtunnel.sh
    fi

    if [ -n "$REMOTE_HOST" ]; then
        # wait until connection is ready
        sleep 1
        for _ in {1..15}; do 
            if ! pgrep -f ssh; then
                info "*** ssh exited, abort ***"
                break
            elif curl --fail -sI -x "socks5h://127.0.0.1:$SOCKS5_PORT" https://google.com; then
                established=true
                break
            fi
            info "***  wait for connection  ***"
            sleep 3
        done

        if [ -z "$established" ]; then
            info "*** ssh connection failed ***"
            tail "$SSH_LOGFILE"
            exit 1
        fi

        info "*** init dns2socks ***"

        # upstream dns server: use dnsmasq server in socks mode
        [ "$MODE" = route ] || DNS2SOCKS_SERVER="$DNSMASQ_SERVER"

        export DNS2SOCKS_SERVER DNS2SOCKS_PORT DNS2SOCKS_LOGFILE
        echocmd /entrypoint.d/dns2socks.sh

        # test upstream dns and dns2socks
        sleep 1
        if ! dig @127.0.0.1 -p "$DNS2SOCKS_PORT" www.google.com; then
            info "*** dns2socks start failed ***"
            tail "$DNS2SOCKS_LOGFILE"
            exit 1
        fi
    else
        unset SOCKS5_PORT DNS2SOCKS_PORT
    fi

    if [ "$MODE" = route ]; then
        info "*** init ip2route ***"

        export IP2ROUTE_DEVICE="tun$LOCAL_TUN"
        export IP2ROUTE_SERVER="127.0.0.1:$DNS2SOCKS_PORT"

        echocmd /entrypoint.d/ip2route.sh | tee -a /config/ip2route.log 2>&1 || {
            info "*** ip2route start failed"
            exit 1
        }
    fi

    # fix NAT loopback in route mode
    lan="$(ip route get "${DNSMASQ_SERVER%:*}" | grep -oP 'dev \K\S+')"
    subnet="$(ip addr show "$lan" | grep -oP 'inet \K\S+')"
    if [ "$lan" != "tun$LOCAL_TUN" ]; then
        case "$MODE" in
            route)
                info "*** fix NAT loopback ***"
                # FORWARD: lan => lan
                echocmd iptables -C FORWARD -i "$lan" -o "$lan" -j ACCEPT ||
                echocmd iptables -I FORWARD -i "$lan" -o "$lan" -j ACCEPT

                # MASQUERADE: tun0 => lan
                echocmd iptables -t nat -C POSTROUTING -s "$subnet" -o "$lan" -j MASQUERADE ||
                echocmd iptables -t nat -I POSTROUTING -s "$subnet" -o "$lan" -j MASQUERADE
                ;;
            serve)
                info "*** enable wan MASQUERADE ***"
                # MASQUERADE: any => lan
                echocmd iptables -t nat -C POSTROUTING -o "$lan" -j MASQUERADE ||
                echocmd iptables -t nat -I POSTROUTING -o "$lan" -j MASQUERADE
                ;;
        esac
    fi

    info "*** init dnsmasq ***"

    # dns2socks as dnsmasq server
    [ "$MODE" = basic ] && DNSMASQ_SERVER="127.0.0.1:$DNS2SOCKS_PORT" || true
    [ "$MODE" = route ] || unset DNSMASQ_IPSET

    export DNSMASQ_INTERFACE DNSMASQ_PORT DNSMASQ_SERVER DNSMASQ_IPSET
    export DNSMASQ_LOGFILE=/config/dnsmasq.log
    /entrypoint.d/dnsmasq.sh

    sleep 1
    if ! dig @127.0.0.1 www.google.com; then
        info "*** dnsmasq start failed ***"
        tail "$DNSMASQ_LOGFILE"
        exit 1
    fi

    info "*** system is ready ***"

    cat <<EOF
socks5:
  127.0.0.1:$SOCKS5_PORT
  ${subnet%/*}:$SOCKS5_PORT
dns2socks:
  127.0.0.1:$DNS2SOCKS_PORT
  ${subnet%/*}:$DNS2SOCKS_PORT
dns:
  127.0.0.1:$DNSMASQ_PORT
  ${subnet%/*}:$DNSMASQ_PORT
EOF

    /entrypoint.d/healthd.sh >> /config/healthd.log 2>&1 &
    wait $!
else
    exec "$@"
fi
