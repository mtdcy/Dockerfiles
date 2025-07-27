#!/bin/bash
#
# options               =
            DNSMASQ_PORT="${DNSMASQ_PORT:-53}"
       DNSMASQ_INTERFACE="${DNSMASQ_INTERFACE:-}"
          DNSMASQ_SERVER="${DNSMASQ_SERVER:-114.114.114.114}"
           DNSMASQ_IPSET="${DNSMASQ_IPSET:-/config/dnsmasq.ipset}"
         DNSMASQ_LOGFILE="${DNSMASQ_LOGFILE:-/var/log/dnsmasq.log}"

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

# advanced settings
[ -f /config/dnsmasq.conf   ] && args+=( --conf-file=/config/dnsmasq.conf   ) || true
[ -d /config/dnsmasq.d      ] && args+=( --conf-dir=/config/dnsmasq.d       ) || true
[ -f /config/dnsmasq.host   ] && args+=( --addn-hosts=/config/dnsmasq.host  ) || true

# ipset settings, do not use '--ipset=...'
[ -f "$DNSMASQ_IPSET"       ] && args+=( --conf-file="$DNSMASQ_IPSET"       ) || true

# basic settings
[ -z "$DNSMASQ_SERVER"      ] || args+=( --server="${DNSMASQ_SERVER//:/#}"  )
[ -z "$DNSMASQ_PORT"        ] || args+=( --port="$DNSMASQ_PORT"             )
[ -z "$DNSMASQ_INTERFACE"   ] || args+=( --bind-interfaces --interface="$DNSMASQ_INTERFACE"   )

# optimized settings
# use servers strictly in the order by given
args+=( --strict-order )
# do not read resolv.conf
args+=( --no-resolv )
# logging to stdout
args+=( --log-queries --log-dhcp --log-facility=- )

dnsmasq=( /usr/sbin/dnsmasq "${args[@]}" )

info "${dnsmasq[*]}"
"${dnsmasq[@]}" -k 2>&1 | ts "[%b %d %H:%M:%S]" | tee -a "$DNSMASQ_LOGFILE" & disown

sleep 1
if [ -z "$(dig @127.0.0.1 "${TEST_DOMAIN:-www.google.com}")" ]; then
    info "dnsmasq start failed"
    tail "$DNSMASQ_LOGFILE"
    exit 1
fi
