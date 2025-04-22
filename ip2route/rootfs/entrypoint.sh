#!/bin/bash -e

info () {
    echo -e "🐳\\033[33m [$(date '+%Y/%m/%d %H:%M:%S')] $* \\033[0m" >&2
}

echocmd() {
    echo -e "--\\033[34m $(tr -s ' ' <<< "$*") \\033[0m"
    eval -- "$*"
}

#       options         .
export              MODE="${MODE:-socks5}" # server,route,socks5
export       SOCKS5_PORT="${SOCKS5_PORT:-1070}"

export       REMOTE_HOST="${REMOTE_HOST:-}" # no def value
export        LOCAL_ADDR="${LOCAL_ADDR:-10.20.30.40}"
export       REMOTE_ADDR="${REMOTE_ADDR:-${LOCAL_ADDR%.*}.1}"
export         LOCAL_TUN="${LOCAL_TUN:-0}"
export        REMOTE_TUN="${REMOTE_TUN:-0}"
export           MAX_TUN="${MAX_TUN:-1}" # server mode

export          SSH_OPTS="${SSH_OPTS:-}"

export DNSMASQ_INTERFACE="${DNSMASQ_INTERFACE:-}" # no def value
export    DNSMASQ_SERVER="${DNSMASQ_SERVER:-114.114.114.114}" # default upstream dns server
export     DNSMASQ_IPSET="${DNSMASQ_IPSET:-/config/dnsmasq.ipset}"
export      DNSMASQ_PORT="${DNSMASQ_PORT:-53}"

export  DNS2SOCKS_SERVER="${DNS2SOCKS_SERVER:-8.8.8.8:53}" # valid only in route mode, use dnsmasq server in socks5 mode
export    DNS2SOCKS_PORT="${DNS2SOCKS_PORT:-5353}"

# Notes:
#
# - DNSMASQ_SERVER: it's for normal dns resolve, should select one for performance.

if [ -z "$*" ]; then
    logfiles=()

    # mount ~/.ssh to /config/ssh => multiple id files exists
    SSH_IDENT="${SSH_IDENT:-/config/ssh/id_ed25519}" # perfer ed25519
    [ -f "$SSH_IDENT" ] || SSH_IDENT="/config/ssh/id_rsa"
    [ -f "$SSH_IDENT" ] || SSH_IDENT="/config/ssh/id_ed25519"

    [ "$MODE" = server ] && REMOTE_HOST= || MAX_TUN=1

    # resolve host first
    if [ -n "$REMOTE_HOST" ]; then
        IFS='@:' read -r user host port <<< "$REMOTE_HOST"
        host=$(dig "@$DNSMASQ_SERVER" "$host" +short)
        [ -z "$host" ] || export REMOTE_HOST="$user@$host:${port:-22}"
    fi

    if [ -n "$REMOTE_HOST" ] || [ "$MODE" = server ]; then
        info "*** init ssh tunnel ***"

        # socks5 server and ssh tunnel
        echocmd /usr/bin/sshtunnel.sh >> /config/sshtunnel.log 2>&1 &
        logfiles+=(/config/sshtunnel.log)

        sleep 3
    fi

    if [ -n "$REMOTE_HOST" ]; then
        # wait until connection is ready
        sleep 1
        if ! pgrep sshtunnel.sh; then
            info "*** no ssh connection, exit... ***"
            cat /config/sshtunnel.log
            exit 1
        fi

        while ! curl --fail -sI -x "socks5h://127.0.0.1:$SOCKS5_PORT" https://google.com &>/dev/null; do
            info "*** wait for connection ... ***"
            sleep 1
        done

        info "*** init dns2socks ***"

        args=( --verbosity debug )
        # upstream dns server, use dnsmasq server in socks mode
        [ "$MODE" = route ] || DNS2SOCKS_SERVER="$DNSMASQ_SERVER"
        IFS=":" read -r dns port <<< "$DNS2SOCKS_SERVER"
        args+=( --dns-remote-server "$dns:${port:-53}" )
        # socks settings
        args+=( --socks5-settings "socks5://127.0.0.1:$SOCKS5_PORT" )
        # bind to localhost
        args+=( --listen-addr "127.0.0.1:$DNS2SOCKS_PORT" )
        # both tcp & udp
        args+=( --force-tcp )
        # quick failure
        args+=( --timeout 1 )

        echocmd /usr/bin/dns2socks "${args[@]}" >> /config/dns2socks.log 2>&1 &
        logfiles+=(/config/dns2socks.log)
    fi

    if [ "$MODE" = route ]; then
        info "*** init ip2route ***"

        export IP2ROUTE_DEV="tun$LOCAL_TUN"
        export IP2ROUTE_SERVER="127.0.0.1:$DNS2SOCKS_PORT"

        echocmd /usr/bin/ip2route.sh >> /config/ip2route.log 2>&1
        logfiles+=(/config/ip2route.log)
    elif [ "$MODE" = socks5 ]; then
        # replace dnsmasq server in socks5 mode
        export DNSMASQ_SERVER="127.0.0.1:$DNS2SOCKS_PORT"
    fi

    # fix NAT loopback in route mode
    if [ "$MODE" = route ]; then
        lan="$(ip route get "${DNSMASQ_SERVER%:*}" | grep -oP 'dev \K\S+')"
        if [ "$lan" != "tun$LOCAL_TUN" ]; then
            info "*** fix NAT loopback ***"

            subnet="$(ip addr show "$lan" | grep -oP 'inet \K\S+')"
            iptables -C FORWARD -i "$lan" -o "$lan" -j ACCEPT ||
            echocmd iptables -I FORWARD -i "$lan" -o "$lan" -j ACCEPT

            iptables -t nat -D POSTROUTING -s "$subnet" -o "$lan" -j MASQUERADE ||
            echocmd iptables -t nat -I POSTROUTING -s "$subnet" -o "$lan" -j MASQUERADE
        fi
    fi

    # enable dnsmasq ipset only in route mode
    [ "$MODE" = route ] || unset DNSMASQ_IPSET

    info "*** setup resolv.conf ***"
    echocmd unlink /etc/resolv.conf 2>/dev/null || true
    cat <<EOF > /etc/resolv.conf
nameserver 127.0.0.1
search local
EOF
    # => please setup resolv.conf in host manually

    info "*** init dnsmasq ***"

    # be carefull with the arguments order
    args=()

    # advanced settings
    [ -f /config/dnsmasq.conf   ] && args+=( --conf-file=/config/dnsmasq.conf   ) || true
    [ -d /config/dnsmasq.d      ] && args+=( --conf-dir=/config/dnsmasq.d       ) || true
    [ -f /config/dnsmasq.host   ] && args+=( --addn-hosts=/config/dnsmasq.host  ) || true

    # ip2route settings, do not use '--ipset=...'
    [ -z "$DNSMASQ_IPSET"       ] || args+=( --conf-file="$DNSMASQ_IPSET"       )

    # basic settings
    [ -z "$DNSMASQ_SERVER"      ] || args+=( --server="${DNSMASQ_SERVER//:/#}"  )
    [ -z "$DNSMASQ_PORT"        ] || args+=( --port="$DNSMASQ_PORT"             )
  
    if [ -n "$DNSMASQ_INTERFACE" ]; then
        args+=( --bind-interfaces --except-interface=lo --interface="$DNSMASQ_INTERFACE" )
    else
        args+=( --bind-dynamic )
    fi

    # optimized settings
    # use servers strictly in the order by given
    args+=( --strict-order )
    # do not read resolv.conf
    args+=( --no-resolv )

    # logging settings
    args+=( --log-queries --log-dhcp --log-facility=/config/dnsmasq.log )
    logfiles+=(/config/dnsmasq.log)

    echocmd /usr/sbin/dnsmasq "${args[@]}"

    #/usr/bin/healthd.sh > /config/healthd.log 2>&1 &

    info "*** system is ready ***"
    echo -e "\n\n"
    tail -f "${logfiles[@]}"
else
    exec "$@"
fi
