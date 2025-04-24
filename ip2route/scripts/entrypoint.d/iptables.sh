#!/bin/bash -e
# 
# iptables.sh tun0
# iptables.sh flush tun0

# options   = 
        MODE="${MODE:-}"

set +H # for !

echocmd() {
    echo -e "--\\033[34m $* \\033[0m" >&2
    "$@"
}

# flush <dev> [-t table]
delete() {
    while read -r rule; do
        [ -n "$rule" ] || continue
        echocmd iptables "${@:2}" ${rule/-A/-D} || true
    done < <(iptables -S "${@:2}" | grep -E -- "-i $1|-o $1")
}

flush() {
    delete "$1"
    delete "$1" -t nat
    delete "$1" -t mangle
}

if [ "$1" = flush ]; then
    flush "$2"
    exit
fi

if [ "$MODE" = serve ]; then
    ## enable INPUT & OUTPUT
    #echocmd iptables -I OUTPUT -o "$1" -j ACCEPT
    #echocmd iptables -I INPUT -i "$1" -j ACCEPT

    # enable FORWARD: dev => any
    echocmd iptables -I FORWARD -i "$1" -j ACCEPT
    echocmd iptables -I FORWARD -o "$1" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

    # enable MASQUERADE for incoming traffics
    net="$(ip addr show "$1" | grep -oP 'inet \K\S+')"
    echocmd iptables -t nat -I POSTROUTING -s "$net" ! -o "$1" -j MASQUERADE
else
    ## enable OUTPUT: any => dev
    #echocmd iptables -I OUTPUT -o "$1" -j ACCEPT
    #echocmd iptables -I INPUT -i "$1" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

    # enable FORWARD: any ==> dev
    echocmd iptables -I FORWARD -o "$1" -j ACCEPT
    echocmd iptables -I FORWARD -i "$1" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

    # enable MASQUERADE
    echocmd iptables -t nat -I POSTROUTING -o "$1" -j MASQUERADE
fi

# ICMP/ping
echocmd iptables -I INPUT -i "$1" -p icmp -j ACCEPT

## IGMP
#echocmd iptables -I INPUT -i "$1" -p igmp -j ACCEPT
## DNS/53
#echocmd iptables -I INPUT -i "$1" -p tcp -m tcp --dport 53 -j ACCEPT
#echocmd iptables -I INPUT -i "$1" -p udp -m udp --dport 53 -j ACCEPT
## DHCP
#echocmd iptables -I INPUT -i "$1" -p udp -m udp --dport 67 -j ACCEPT
#echocmd iptables -I INPUT -i "$1" -p udp -m udp --dport 68 -j ACCEPT

# enable TCPMSS
tcpmss=( -p tcp -m tcp --tcp-flags "SYN,RST" SYN -j TCPMSS --clamp-mss-to-pmtu )
echocmd iptables -t mangle -I FORWARD -o "$1" "${tcpmss[@]}"
