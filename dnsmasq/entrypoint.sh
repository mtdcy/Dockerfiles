#!/bin/bash -e
# shellcheck disable=SC2015
# shellcheck disable=SC2034

RED="\\033[31m"
GREEN="\\033[32m"
YELLOW="\\033[33m"
BLUE="\\033[34m"
PURPLE="\\033[35m"
CYAN="\\033[36m"
NC="\\033[0m"

# setup timezone
if test -n "$TZ"; then
    ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
    echo "$TZ" > /etc/timezone
fi

if [ $# -gt 0 ] && which "$1" &>/dev/null; then
    "$@"
    exit
fi

# setup dnsmasq.conf
#  => no 'log-facility' here, the first effective.
if ! test -f /config/dnsmasq.conf; then
    cat << EOF > /config/dnsmasq.conf
# dnsmasq.conf - $(date)

# log
log-dhcp
log-queries=extra

## bind
port=53
bind-dynamic

# resolv
no-hosts        # no /etc/hosts
no-resolv       # no /etc/resolv.conf
strict-order    # query the first server
server=1.1.1.1  # lowest priority server

# misc
cache-size=1024

# dhcp examples >> Please use host network mode <<
#dhcp-range=192.168.100.2,192.168.100.99,255.255.255.0,12h
#dhcp-option=option:router,192.168.100.1
#dhcp-option=option:dns-server,114.114.114.114,223.5.5.5
#dhcp-option=option:domain-search,local

conf-dir=/config/dnsmasq.d
EOF
fi

# prefer configs here
mkdir -p /config/dnsmasq.d

opts=(
    --keep-in-foreground
    --conf-file=/config/dnsmasq.conf
)

# ---
# ** define a few options to simplify things **
#
# append options after config file:
#  => options has higher priority.
#  => but some options is the first effective.
# ---

if test -n "$DNSMASQ_SERVERS"; then
    IFS=' ' read -r -a servers <<< "$(eval echo "$DNSMASQ_SERVERS")"
    for s in "${servers[@]}"; do
        opts+=("--server=$s")
    done
fi

# prefer define dhcp server in dnsmasq.d
if test -n "$DNSMASQ_DHCP_ROUTER"; then
cat << EOF
$(echo -e "$YELLOW")
    ---
    'no address range available for DHCP request via eth0'

    dhcp server is not easy to work with bridge network,
    the simplest way to get dhcp working with docker is
    to use host network mode.
    ---
$(echo -e "$NC")
EOF
    prefix="${DNSMASQ_DHCP_ROUTER%.*}"
    opts+=("--dhcp-range=$prefix.2,$prefix.99,255.255.255.0,12h")
    opts+=("--dhcp-option=option:router,$DNSMASQ_DHCP_ROUTER") # gateway
    if test -n "$DNSMASQ_DHCP_SERVERS"; then
        IFS=' ,' read -r -a dns <<< "$(eval echo "$DNSMASQ_DHCP_SERVERS")"
        opts+=("--dhcp-option=option:dns-server,${dns[@]// /,}")
    else
        opts+=("--dhcp-option=option:dns-server,$DNSMASQ_DHCP_ROUTER") # default dns: gateway
    fi
    opts+=("--dhcp-option=option:domain-search,local")
fi

if test -n "$DNSMASQ_OPTS"; then
    IFS=' ' read -r -a kvs <<< "$(eval echo "$DNSMASQ_OPTS")"
    opts+=("${kvs[@]}")
fi

# append user options
opts+=("$@")

# log to stderr by default
#  => it seems dnsmasq don't support log to stdout
if ! grep -qR 'log-facility=' /config/dnsmasq* &&
   ! [[ "${opts[*]}" =~ log-facility ]]; then
    opts+=("--log-facility=-")
fi

echo "dnsmasq ${opts[*]}"
eval "dnsmasq ${opts[*]}"
