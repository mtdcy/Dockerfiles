#!/bin/bash

#       options         =
export              MODE="${MODE:-basic}" # basic,route,serve
export            ROUTES="${ROUTES:-}" # route mode only

export       SOCKS5_PORT="${SOCKS5_PORT:-1070}"
export     SSHSOCKS_PORT="${SSHSOCKS_PORT:-$((SOCKS5_PORT + 1000))}"

export      DNSMASQ_PORT="${DNSMASQ_PORT:-53}"
export    DNS2SOCKS_PORT="${DNS2SOCKS_PORT:-$((DNSMASQ_PORT + 1000))}"

export       REMOTE_HOST="${REMOTE_HOST:-}" # no def value

# preferred tunnel/ssh
export          SSH_ADDR="${SSH_ADDR:-10.20.30.40/24}"
export        SSH_REMOTE="${SSH_REMOTE:-${SSH_ADDR%.*}.1}"
export           SSH_TUN="${SSH_TUN:-tun0}"
export    SSH_TUN_REMOTE="${SSH_TUN_REMOTE:-$SSH_TUN}"
export         SSH_COUNT="${SSH_COUNT:-1}" # serve mode
export         SSH_IDENT="${SSH_IDENT:-/config/ssh/id_ed25519}" # perfer ed25519
export          SSH_OPTS="${SSH_OPTS:-}"

# n2n tunnel
export           N2N_KEY="${N2N_KEY:-}"
export          N2N_PORT="${N2N_PORT:-}"
export          N2N_ADDR="${N2N_ADDR:-$SSH_ADDR}"
export        N2N_REMOTE="${N2N_REMOTE:-${N2N_ADDR%.*}.1}"
export        N2N_DEVICE="${N2N_DEVICE:-n2n0}"

# dns server
export DNSMASQ_INTERFACE="${DNSMASQ_INTERFACE:-}" # no def value
export    DNSMASQ_SERVER="${DNSMASQ_SERVER:-114.114.114.114}" # upstream dns server

export       TEST_DOMAIN="${TEST_DOMAIN:-www.baidu.com}"

# Notes:
#
# - DNSMASQ_SERVER: it's for normal dns resolve, ip route get should return default.

info () {
    echo -e "🐳\\033[33m $* \\033[0m🐳" >&2
}

echocmd() {
    echo -e "--\\033[34m $* \\033[0m"
    eval -- "$*"
}

clean() {
    info "***** clean *****"

    # clean explicitly
    [ -z "$SSH_ADDR"    ] || /entrypoint.d/sshtunnel.sh clean || true
    [ -z "$N2N_ADDR"    ] || /entrypoint.d/n2n.sh clean || true
    [ "$MODE" = route   ] && /entrypoint.d/ip2route.sh clean || true

    pkill -INT  ssh || true
    pkill -INT  dns2socks || true
    pkill -USR1 dnsmasq || true

    sleep 1
}

[ -z "$*" ] || exec "$@"

trap clean EXIT

set -eo pipefail

info "***** Mode: $MODE ****"

[ -e /config/logs ] || mkdir -p /config/logs
chown nobody:root /config/logs

info "***** prepare host ****"

# test dns server
IFS=':' read -r dns dns_port <<< "$DNSMASQ_SERVER"
echocmd dig "@$dns" -p "${dns_port:-53}" "$TEST_DOMAIN"

# host dns may not work when container is starting
if [ -n "$REMOTE_HOST" ]; then
    IFS='@:' read -r user host port <<< "${REMOTE_HOST#*//}"
    host="$(dig "@$dns" -p "${dns_port:-53}" "$host" +short)"
    [ -z "$host" ] || export REMOTE_HOST="${REMOTE_HOST%//*}//$user@$host:${port:-22}"
fi

lan="$(ip route get "${DNSMASQ_SERVER%:*}" | grep -oP 'dev \K\S+')"
net="$(ip addr show "$lan" | grep -oP 'inet \K\S+')"

export SSH_LOGFILE=/config/logs/sshtunnel.log

info "***** prepare tunnel *****"

case "$MODE" in
    serve)
        # no remote addr in serve mode
        unset -v SSH_REMOTE N2N_REMOTE

        echocmd /entrypoint.d/sshtunnel.sh

        case "$REMOTE_HOST" in
            n2n://*)
                N2N_LOGFILE=/config/logs/n2n.log
                export N2N_KEY N2N_DEVICE N2N_LOGFILE
                echocmd /entrypoint.d/n2n.sh
                ;;
        esac

        unset -v SOCKS5_PORT DNS2SOCKS_PORT
        ;;
    *)
        case "$REMOTE_HOST" in
            n2n://*) # 1:N tunnel
                unset -v SSH_ADDR SSH_REMOTE SSHSOCKS_PORT

                N2N_LOGFILE=/config/logs/n2n.log
                export N2N_KEY N2N_DEVICE N2N_LOGFILE
                echocmd /entrypoint.d/n2n.sh

                IP2ROUTE_DEVICE="$N2N_DEVICE"
                IP2ROUTE_SERVER="$N2N_REMOTE"
                DNS2SOCKS_SERVER="$N2N_REMOTE"
                ;;
            ssh://*|*) # 1:1 tunnel
                unset -v N2N_ADDR N2N_REMOTE
                # sanity check
                [ "$MODE" = route ] || unset -v SSH_ADDR SSH_REMOTE

                echocmd /entrypoint.d/sshtunnel.sh

                IP2ROUTE_DEVICE="$SSH_TUN"
                IP2ROUTE_SERVER="$SSH_REMOTE"
                DNS2SOCKS_SERVER="$SSH_REMOTE"
                ;;
        esac
        ;;
esac

info "***** prepare iptables *****"

case "$MODE" in
    route)
        info "***** fix NAT loopback @$lan *****"
        # FORWARD: lan => lan
        echocmd iptables -C FORWARD -i "$lan" -o "$lan" -j ACCEPT ||
        echocmd iptables -I FORWARD -i "$lan" -o "$lan" -j ACCEPT

        # MASQUERADE: tun0 => lan
        echocmd iptables -t nat -C POSTROUTING -s "$net" -o "$lan" -j MASQUERADE ||
        echocmd iptables -t nat -I POSTROUTING -s "$net" -o "$lan" -j MASQUERADE

        DNSMASQ_IPSET="/config/dnsmasq.ipset"
        export IP2ROUTE_SERVER IP2ROUTE_DEVICE DNSMASQ_IPSET

        echocmd /entrypoint.d/ip2route.sh 2>&1 | tee -a /config/logs/ip2route.log || {
            info "***** ip2route start failed *****"
            exit 1
        }
        ;;
    serve)
        info "***** enable MASQUERADE @$lan *****"
        # MASQUERADE: any => lan
        echocmd iptables -t nat -C POSTROUTING -o "$lan" -j MASQUERADE ||
        echocmd iptables -t nat -I POSTROUTING -o "$lan" -j MASQUERADE
        ;;
esac

if [ -n "$ROUTES" ]; then
    IFS=',' read -r -a _nets <<< "$ROUTES"
    for x in ${_nets[@]}; do
        IFS='@' read -r _net _gw <<< "$x"
        echocmd ip route add "$_net" via "$_gw" proto static ||
        echocmd ip route rep "$_net" via "$_gw" proto static
    done
fi

if [ -n "$DNS2SOCKS_PORT" ]; then
    info "***** prepare socks5 server *****"

    SOCKS5_LOGFILE=/config/logs/socks.log
    [ -z "$SSHSOCKS_PORT" ] || SOCKS5_FORWARD="socks5://127.0.0.1:$SSHSOCKS_PORT"

    export SOCKS5_PORT SOCKS5_FORWARD SOCKS5_LOGFILE
    echocmd /entrypoint.d/socks5.sh

    info "***** prepare dns2socks *****"

    DNS2SOCKS_LOGFILE=/config/logs/dns2socks.log
    # upstream dns server: use dnsmasq server in socks mode
    [ "$MODE" = route ] || DNS2SOCKS_SERVER="$DNSMASQ_SERVER"

    export DNS2SOCKS_SERVER DNS2SOCKS_PORT DNS2SOCKS_LOGFILE
    echocmd /entrypoint.d/dns2socks.sh

    IP2ROUTE_DEVICE="$SSH_TUN"
    IP2ROUTE_SERVER="127.0.0.1:$DNS2SOCKS_PORT"
fi

info "***** prepare dns server *****"

# dns2socks as dnsmasq server
[ "$MODE" = basic ] && DNSMASQ_SERVER="127.0.0.1:$DNS2SOCKS_PORT" || true
# no ipset if not in route mode
[ "$MODE" = route ] || unset -v DNSMASQ_IPSET

DNSMASQ_LOGFILE=/config/logs/dnsmasq.log
export DNSMASQ_INTERFACE DNSMASQ_PORT DNSMASQ_SERVER DNSMASQ_IPSET DNSMASQ_LOGFILE
/entrypoint.d/dnsmasq.sh

info "***** system ready *****"

export TEST_DOMAIN="www.google.com"
su nobody -s /bin/bash -c /entrypoint.d/healthd.sh 2>&1 | tee -a /config/logs/healthd.log & wait $!
