#!/bin/bash

#       options         =
export              MODE="${MODE:-basic}" # basic,route,serve

export       REMOTE_HOST="${REMOTE_HOST:-}"         # user@remote:port

export        LOCAL_ADDR="${LOCAL_ADDR:-10.0.0.1/24}"
export       REMOTE_ADDR="${REMOTE_ADDR:-}"
export      LOCAL_DEVICE="${LOCAL_DEVICE:-tun0}"
export     REMOTE_DEVICE="${REMOTE_DEVICE:-$LOCAL_DEVICE}"
export       SOCKS5_PORT="${SOCKS5_PORT:-1070}"

# dns server [optional]
export      DNSMASQ_PORT="${DNSMASQ_PORT:-}"        # dns port
export DNSMASQ_INTERFACE="${DNSMASQ_INTERFACE:-}"   # no def value
export    DNSMASQ_SERVER="${DNSMASQ_SERVER:-114.114.114.114}" # upstream dns server

# extra options
export          SSH_OPTS="${SSH_OPTS:-}"

# n2n network
export        N2N_DEVICE="${N2N_DEVICE}"
export          N2N_ADDR="${N2N_ADDR:-$LOCAL_ADDR}"
export           N2N_KEY="${N2N_KEY:-}"
export          N2N_OPTS="${N2N_OPTS:-}"

export               WAN="${WAN:-$(ip route show default | head -n1 | grep -oP 'dev \K\S+')}"
export               LAN="${LAN:-$WAN}"

export        ROUTE_FILE="${ROUTE_FILE:-/config/route/route.lst}"

export       TEST_DOMAIN="${TEST_DOMAIN:-www.baidu.com}"

# Notes:
#
# - DNSMASQ_SERVER: it's for normal dns resolve, ip route get should return default.

iptables="${iptables:-$(which iptables)}"
if "$iptables" -S 2>&1 | grep -Fw "Invalid argument"; then
    iptables="$(which iptables-legacy)"
fi
export iptables

info () {
    echo -e "🐳\\033[33m $* \\033[0m🐳" >&2
}

echocmd() {
    echo -e "--\\033[34m $* \\033[0m"
    eval -- "$*"
}

clean() {
    info "***** clean *****"

    pkill -INT  gost || true
    pkill -INT  dns2socks || true
    pkill -USR1 dnsmasq || true

    sleep 1

    # clean explicitly
    case "$REMOTE_HOST" in
        n2n://*)    /entrypoint.d/n2n.sh clean          || true ;;
        *)          /entrypoint.d/sshtunnel.sh clean    || true ;;
    esac

    [ "$MODE" = route ] && /entrypoint.d/ip2route.sh clean || true
}

[ -z "$*" ] || exec "$@"

trap clean EXIT

set -eo pipefail

info "***** Mode: $MODE ****"

mkdir -p /config/logs
chown nobody:root /config/logs

# simple logrotate
find /config/logs -name "*.log" -exec gzip -f {} \;

info "***** prepare host ****"

# test dns server
IFS=':' read -r dns dns_port <<< "$DNSMASQ_SERVER"
echocmd dig "@$dns" -p "${dns_port:-53}" "$TEST_DOMAIN"

# host dns may not work when container is starting
if [ -n "$REMOTE_HOST" ]; then
    IFS='@:' read -r user host port <<< "${REMOTE_HOST#*//}"
    host="$(dig "@$dns" -p "${dns_port:-53}" "$host" +short | tail -1)"
    [ -z "$host" ] || export REMOTE_HOST="${REMOTE_HOST%//*}//$user@$host:${port:-22}"
fi

info "***** prepare sysctl *****"

echocmd /entrypoint.d/sysctl.sh

info "***** prepare tunnel *****"

export SSH_LOGFILE=/config/logs/sshtunnel.log
export N2N_LOGFILE=/config/logs/n2n.log
case "$MODE" in
    serve)
        # no remote addr in serve mode
        unset -v REMOTE_ADDR SOCKS5_PORT

        info "***** prepare ssh tunnel *****"

        echocmd /entrypoint.d/sshtunnel.sh

        if [ -n "$N2N_DEVICE" ]; then
            info "***** prepare n2n server *****"

            export N2N_DEVICE N2N_ADDR N2N_KEY N2N_OPTS
            echocmd /entrypoint.d/n2n.sh
        fi
        ;;
    *)
        case "$REMOTE_HOST" in
            n2n://*) # 1:N tunnel
                info "***** prepare n2n edge *****"

                echocmd /entrypoint.d/n2n.sh

                info "***** prepare socks5 server *****"

                SOCKS5_FORWARD="socks5://127.0.0.1"
                SOCKS5_LOGFILE=/config/logs/socks.log
                export SOCKS5_PORT SOCKS5_FORWARD SOCKS5_LOGFILE

                echocmd /entrypoint.d/socks5.sh
                ;;
            ssh://*|*) # 1:1 tunnel
                # sanity check
                [ "$MODE" = route ] || unset -v LOCAL_ADDR REMOTE_ADDR

                info "***** prepare ssh tunnel *****"

                echocmd /entrypoint.d/sshtunnel.sh
                ;;
        esac
        ;;
esac

export RULES_FILE=/config/afw.rules
if [ "$MODE" = route ] && [ -f "$RULES_FILE" ]; then
    info "***** prepare firewall *****"

    echocmd /entrypoint.d/afw.sh

    ROUTE_DEVICE="$LOCAL_DEVICE"
    ROUTE_ADDR="$REMOTE_ADDR"
    export ROUTE_DEVICE ROUTE_ADDR ROUTE_FILE ROUTE_FLUSH
    
    info "***** prepare ip2route @$ROUTE_DEVICE => $ROUTE_ADDR *****"

    echocmd /entrypoint.d/ip2route.sh
fi

# hack: n2n gateway mode
if [[ "$REMOTE_HOST" =~ ^n2n:// ]] && [ -z "$REMOTE_ADDR" ]; then
    info "***** no socks or dns server for n2n gateway *****"
    info "*****  ** no gateway, access restricted. **  *****"
    while sleep 15; do echocmd ping -c 1 -q "${LOCAL_ADDR%/*}"; done & wait $!
    exit
fi

if [ -n "$DNSMASQ_PORT" ]; then
    # no ipset if not in route mode
    [ "$MODE" = route ] || unset -v DNSMASQ_IPSET

    case "$MODE" in 
        basic)
            info "***** prepare dns2socks *****"

            export DNS2SOCKS_PORT=1053
            export DNS2SOCKS_SERVER="$DNSMASQ_SERVER"
            export DNS2SOCKS_LOGFILE=/config/logs/dns2socks.log

            echocmd /entrypoint.d/dns2socks.sh

            # dns2socks as dnsmasq upstream server
            DNSMASQ_SERVER="127.0.0.1:$DNS2SOCKS_PORT"
            ;;
    esac

    info "***** prepare dns server *****"

    export DNSMASQ_DIR=/config/
    export DNSMASQ_LOGFILE="$DNSMASQ_DIR/logs/dnsmasq.log"
    export DNSMASQ_PORT DNSMASQ_INTERFACE DNSMASQ_SERVER DNSMASQ_IPSET

    /entrypoint.d/dnsmasq.sh
fi

if ss -tunlp | grep -Fwq ":5201"; then
    info "***** skip iperf3 as 5201 already in use *****"
else
    info "***** prepare iperf3 @5201 *****"
    /usr/bin/iperf3 -s | tee -a /config/logs/iperf3.log 2>&1 & disown
fi

info "***** system ready *****"

ps aux

info "***** start healthd *****"

export HEALTHD_LOGFILE=/config/logs/healthd.log

/entrypoint.d/healthd.sh & wait $!
