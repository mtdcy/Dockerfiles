#!/bin/bash -e

info () {
    echo -e "🐳\\033[33m [$(date '+%Y/%m/%d %H:%M:%S')] $* \\033[0m" >&2
}

echocmd() {
    echo -e "--\\033[34m $(tr -s ' ' <<< "$*") \\033[0m"
    eval -- "$*"
}

#       options         .
export              MODE="${MODE:-socks5}" # route,socks5
export       SOCKS5_PORT="${SOCKS5_PORT:-1070}"

export       REMOTE_HOST="${REMOTE_HOST:-}" # no def value
export        LOCAL_ADDR="${LOCAL_ADDR:-10.20.30.40}"
export       REMOTE_ADDR="${REMOTE_ADDR:-${LOCAL_ADDR%.*}.1}"
export         LOCAL_TUN="${LOCAL_TUN:-0}"
export        REMOTE_TUN="${REMOTE_TUN:-0}"

export          SSH_OPTS="${SSH_OPTS:-}"

export DNSMASQ_INTERFACE="${DNSMASQ_INTERFACE:-}" # no def value
export    DNSMASQ_SERVER="${DNSMASQ_SERVER:-114.114.114.114}" # default upstream dns server
export     DNSMASQ_IPSET="${DNSMASQ_IPSET:-/config/dnsmasq.ipset}"

# Notes:
#
# - DNSMASQ_SERVER: it's for normal dns resolve, should select one for performance.

if [ -z "$*" ]; then
    logfiles=()

    # mount ~/.ssh to /config/ssh => multiple id files exists
    SSH_IDENT="${SSH_IDENT:-/config/ssh/id_ed25519}" # perfer ed25519
    [ -f "$SSH_IDENT" ] || SSH_IDENT="/config/ssh/id_rsa"
    [ -f "$SSH_IDENT" ] || SSH_IDENT="/config/ssh/id_ed25519"

    if [ -n "$REMOTE_HOST" ]; then
        info "*** init ssh tunnel ***"

        # resolve host first
        IFS='@:' read -r user host port <<< "$REMOTE_HOST"
        host=$(dig "@$DNSMASQ_SERVER" "$host" +short)
        [ -z "$host" ] || export REMOTE_HOST="$user@$host:${port:-22}"

        # socks5 server and ssh tunnel
        echocmd /usr/bin/sshtunnel.sh > /config/sshtunnel.log 2>&1 &
        logfiles+=(/config/sshtunnel.log)

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

        # 1. always use 8.8.8.8 as upstream dns server
        # 2. force tcp, otherwise dns2socks won't work sometimes.
        echocmd /usr/bin/dns2socks                              \
            --force-tcp                                         \
            --verbosity debug                                   \
            --listen-addr 127.0.0.1:1053                        \
            --dns-remote-server 8.8.8.8:53                      \
            --socks5-settings "socks5://127.0.0.1:$SOCKS5_PORT" \
            --timeout 1                                         \
            > /config/dns2socks.log 2>&1 &
        logfiles+=(/config/dns2socks.log)

        if [ "$MODE" = route ]; then
            info "*** init ip2route ***"

            export IP2ROUTE_DEV="tun$LOCAL_TUN"
            export IP2ROUTE_SERVER="127.0.0.1:1053"
            echocmd /usr/bin/ip2route.sh

            lan="$(ip route get "$DNSMASQ_SERVER" | grep -oP 'dev \K\S+')"
            if [ "$lan" != "tun$LOCAL_TUN" ]; then
                info "*** fix NAT loopback ***"

                subnet="$(ip addr show "$lan" | grep -oP 'inet \K\S+')"
                iptables -C FORWARD -i "$lan" -o "$lan" -j ACCEPT ||
                echocmd iptables -I FORWARD -i "$lan" -o "$lan" -j ACCEPT

                iptables -t nat -D POSTROUTING -s "$subnet" -o "$lan" -j MASQUERADE ||
                echocmd iptables -t nat -I POSTROUTING -s "$subnet" -o "$lan" -j MASQUERADE
            fi
        else
            # append dns2socks to dnsmasq if not in host mode
            export DNS2SOCKS_SERVER=127.0.0.1:1053

            # enable dnsmasq ipset only in host mode
            unset DNSMASQ_IPSET
        fi
    else
        # no ssh socks or tunnel
        unset DNSMASQ_IPSET
    fi

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

    # dns2socks settings
    [ -z "$DNS2SOCKS_SERVER"    ] || args+=( --server="${DNS2SOCKS_SERVER//:/#}")

    # ip2route settings, do not use '--ipset=...'
    [ -z "$DNSMASQ_IPSET"       ] || args+=( --conf-file="$DNSMASQ_IPSET"       )

    # basic settings
    [ -z "$DNSMASQ_SERVER"      ] || args+=( --server="$DNSMASQ_SERVER"         )
  
    if [ -n "$DNSMASQ_INTERFACE" ]; then
        args+=( --interface="$DNSMASQ_INTERFACE" )
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
