#!/bin/bash

#       options         =
export              MODE="${MODE:-basic}" # basic,route,serve
export            ROUTES="${ROUTES:-}" # route mode only

export       SOCKS5_PORT="${SOCKS5_PORT:-1070}"
export      DNSMASQ_PORT="${DNSMASQ_PORT:-53}"

export       REMOTE_HOST="${REMOTE_HOST:-}" # no def value

export        LOCAL_ADDR="${LOCAL_ADDR:-10.0.0.1/24}"
export       REMOTE_ADDR="${REMOTE_ADDR:-}"
export      LOCAL_DEVICE="${LOCAL_DEVICE:-tun0}"
export     REMOTE_DEVICE="${REMOTE_DEVICE:-$LOCAL_DEVICE}"
export      DEVICE_COUNT="${DEVICE_COUNT:-1}" # ssh serve mode only

# dns server
export DNSMASQ_INTERFACE="${DNSMASQ_INTERFACE:-}" # no def value
export    DNSMASQ_SERVER="${DNSMASQ_SERVER:-114.114.114.114}" # upstream dns server

# extra options
export     SSHSOCKS_PORT="${SSHSOCKS_PORT:-$((SOCKS5_PORT + 1000))}"
export    DNS2SOCKS_PORT="${DNS2SOCKS_PORT:-$((DNSMASQ_PORT + 1000))}"

export          SSH_OPTS="${SSH_OPTS:-}"
export           N2N_KEY="${N2N_KEY:-}"
export          N2N_OPTS="${N2N_OPTS:-}"

export               WAN="${WAN:-$(ip route show default | head -n1 | grep -oP 'dev \K\S+')}"
export               NET="${NET:-$(ip addr show "$WAN" | grep -oP 'inet \K\S+')}"

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

[ -e /config/logs ] || mkdir -p /config/logs
chown nobody:root /config/logs

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
        unset -v REMOTE_ADDR SSHSOCKS_PORT

        echocmd /entrypoint.d/sshtunnel.sh

        echocmd /entrypoint.d/n2n.sh
        ;;
    *)
        case "$REMOTE_HOST" in
            n2n://*) # 1:N tunnel
                unset -v SSHSOCKS_PORT

                echocmd /entrypoint.d/n2n.sh
                ;;
            ssh://*|*) # 1:1 tunnel
                # sanity check
                [ "$MODE" = route ] || unset -v LOCAL_ADDR REMOTE_ADDR

                echocmd /entrypoint.d/sshtunnel.sh
                ;;
        esac
        ;;
esac

info "***** prepare routes *****"

# no routes in basic mode
[ "$MODE" = route ] || unset -v ROUTES

if [ -n "$ROUTES" ]; then
    IFS=',' read -r -a _nets <<< "$ROUTES"
    for x in ${_nets[@]}; do
        IFS='@' read -r _net _gw <<< "$x"
        [ -n "$_gw" ] || _gw="$REMOTE_ADDR"
        [ -n "$_gw" ] || _gw="${LOCAL_ADDR%/*}"

        info "***** add route $_net @$_gw *****"
        echocmd ip route add "$_net" via "$_gw" dev "$LOCAL_DEVICE" proto static onlink ||
        echocmd ip route rep "$_net" via "$_gw" dev "$LOCAL_DEVICE" proto static onlink ||
        # Error: Nexthop has invalid gateway.
        echocmd ip route add "$_net" via "$_gw" proto static ||
        echocmd ip route rep "$_net" via "$_gw" proto static ||
        info "***** add route $_net failed *****"
    done
fi

# hack: n2n gateway mode
if [[ "$REMOTE_HOST" =~ ^n2n:// ]] && [ -z "$REMOTE_ADDR" ]; then
    info "***** no socks or dns server for n2n gateway *****"
    info "*****  ** no gateway, access restricted. **  *****"
    while sleep 15; do echocmd ping -c 1 -q "${LOCAL_ADDR%/*}"; done & wait $!
    exit
fi

info "***** prepare iptables *****"

case "$MODE" in
    route)
        info "***** fix NAT loopback @$WAN *****"
        # FORWARD: lan => lan
        echocmd "$iptables" -C FORWARD -i "$WAN" -o "$WAN" -j ACCEPT ||
        echocmd "$iptables" -I FORWARD -i "$WAN" -o "$WAN" -j ACCEPT

        # MASQUERADE: tun0 => lan
        echocmd "$iptables" -t nat -C POSTROUTING -s "$NET" -o "$WAN" -j MASQUERADE ||
        echocmd "$iptables" -t nat -I POSTROUTING -s "$NET" -o "$WAN" -j MASQUERADE

        echocmd /entrypoint.d/ip2route.sh || {
            info "***** ip2route start failed *****"
            exit 1
        }
        ;;
    serve)
        info "***** enable MASQUERADE @$WAN *****"
        # MASQUERADE: any => lan
        echocmd "$iptables" -t nat -C POSTROUTING -o "$WAN" -j MASQUERADE ||
        echocmd "$iptables" -t nat -I POSTROUTING -o "$WAN" -j MASQUERADE
        ;;
esac

info "***** prepare socks5 server *****"

[ -z "$SSHSOCKS_PORT" ] || SOCKS5_FORWARD="socks5://127.0.0.1:$SSHSOCKS_PORT"

SOCKS5_LOGFILE=/config/logs/socks.log
export SOCKS5_PORT SOCKS5_FORWARD SOCKS5_LOGFILE

echocmd /entrypoint.d/socks5.sh

case "$MODE" in
    basic)
        info "***** prepare dns2socks *****"

        DNS2SOCKS_LOGFILE=/config/logs/dns2socks.log
        # upstream dns server: use dnsmasq server in basic mode
        DNS2SOCKS_SERVER="$DNSMASQ_SERVER"
        export DNS2SOCKS_SERVER DNS2SOCKS_PORT DNS2SOCKS_LOGFILE

        echocmd /entrypoint.d/dns2socks.sh

        # dns2socks as dnsmasq upstream server
        DNSMASQ_SERVER="127.0.0.1:$DNS2SOCKS_PORT"
        ;;
    *)
        unset -v DNS2SOCKS_PORT
        ;;
esac

info "***** prepare dns server *****"

# no ipset if not in route mode
[ "$MODE" = route ] || unset -v DNSMASQ_IPSET

DNSMASQ_LOGFILE=/config/logs/dnsmasq.log
export DNSMASQ_INTERFACE DNSMASQ_PORT DNSMASQ_SERVER DNSMASQ_IPSET DNSMASQ_LOGFILE

/entrypoint.d/dnsmasq.sh

export RULES_FILE=/config/afw.rules
if [ -f "$RULES_FILE" ]; then
    info "***** prepare afw firewall *****"
    /entrypoint.d/afw.sh
fi

if ss -tunlp | grep -Fwq 5201; then
    info "***** skip iperf3 as 5201 already in use *****"
else
    info "***** prepare iperf3 @5201 *****"
    /usr/bin/iperf3 -s > /config/iperf3.log 2>&1 & disown
fi

info "***** system ready *****"

su nobody -s /bin/bash -c /entrypoint.d/healthd.sh 2>&1 | tee -a /config/logs/healthd.log & wait $!
