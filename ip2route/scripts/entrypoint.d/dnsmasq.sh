#!/bin/bash
#
# options               =
            DNSMASQ_PORT="${DNSMASQ_PORT:-53}"
       DNSMASQ_INTERFACE="${DNSMASQ_INTERFACE:-}"
          DNSMASQ_SERVER="${DNSMASQ_SERVER:-114.114.114.114}"
             DNSMASQ_DIR="${DNSMASQ_DIR:-/etc/dnsmasq}"
         DNSMASQ_LOGFILE="${DNSMASQ_LOGFILE:-$DNSMASQ_DIR/dnsmasq.log}"

info() {
    echo -e "🚀\\033[32m $* \\033[0m🚀"
}

echocmd() {
    echo -e "--\\033[34m $* \\033[0m"
    "$@"
}

info "init dnsmasq @localhost:$DNSMASQ_PORT => $DNSMASQ_SERVER"

# be carefull with the arguments order
args=()

# basic settings
[ -z "$DNSMASQ_SERVER"      ] || args+=( --server="${DNSMASQ_SERVER//:/#}"  )
[ -z "$DNSMASQ_PORT"        ] || args+=( --port="$DNSMASQ_PORT"             )

# binding settings 
if [ -n "$DNSMASQ_INTERFACE"   ]; then
    args+=( --bind-interfaces --interface="$DNSMASQ_INTERFACE" )
else
    args+=( --bind-dynamic )
fi

# optimized settings
# use servers strictly in the order by given
args+=( --strict-order )
# do not read resolv.conf
args+=( --no-resolv )
# logging to stdout
args+=( --log-facility=- )

# advanced settings
[ -f "$DNSMASQ_DIR/dnsmasq.conf"    ] && args+=( --conf-file="$DNSMASQ_DIR/dnsmasq.conf"    ) || true
[ -d "$DNSMASQ_DIR/dnsmasq.d"       ] && args+=( --conf-dir="$DNSMASQ_DIR/dnsmasq.d"        ) || true
[ -f "$DNSMASQ_DIR/dnsmasq.host"    ] && args+=( --addn-hosts="$DNSMASQ_DIR/dnsmasq.host"   ) || true

# ipset settings, do not use '--ipset=...'
[ -f "$DNSMASQ_DIR/dnsmasq.ipset"   ] && args+=( --conf-file="$DNSMASQ_DIR/dnsmasq.ipset"   ) || true

dnsmasq=( /usr/sbin/dnsmasq "${args[@]}" )

info "${dnsmasq[*]}"
"${dnsmasq[@]}" -k 2>&1 | ts "[%b %d %H:%M:%S]" | tee -a "$DNSMASQ_LOGFILE" & disown

sleep 1
if [ -z "$(dig @127.0.0.1 "${TEST_DOMAIN:-www.google.com}")" ]; then
    info "dnsmasq start failed"
    tail "$DNSMASQ_LOGFILE"
    exit 1
fi
