#!/bin/bash -e
# 
# iptables.sh tun0 [gw]
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

# flush <dev>
flush() {
    delete "$1" || true
    delete "$1" -t nat || true
    delete "$1" -t mangle || true
    
    while read -r line; do
        IFS=' ' read -r _net _ <<< "$line"
        echocmd ip route del "$_net"
    done < <(ip route show | grep -Fw "dev $1")

    echocmd ip addr flush dev "$1" || true
}

case "$1" in
    flush)
        shift
        flush "$1"
        exit
        ;;
esac

# ip
dev="$1"
net="$2"
ngw="$3"

if [ -z "$net" ]; then
    net="$(ip addr show "$dev" | grep -oP 'inet \K\S+')"
else
    flush "$dev"

    echocmd ip addr add "$net" brd + dev "$dev" || true
    echocmd ip link set "$dev" up || true
fi

[[ "$net" =~ / ]] || net="$net/24"

# 'RTNETLINK answers: File exists'
if [ -n "$ngw" ]; then
    # Error: Nexthop has invalid gateway.
    echocmd ip route add "$net" via "$ngw" dev "$dev" || {
        echocmd ip route add "$ngw" dev "$dev"
        echocmd ip route add "$net" via "$ngw" || true
    }
else
    echocmd ip route add "$net" dev "$dev" || true
fi

if [ "$MODE" = serve ]; then
    ## enable INPUT & OUTPUT
    #echocmd iptables -I OUTPUT -o "$dev" -j ACCEPT
    #echocmd iptables -I INPUT -i "$dev" -j ACCEPT

    # enable FORWARD: dev => any
    echocmd iptables -I FORWARD -i "$dev" -j ACCEPT
    echocmd iptables -I FORWARD -o "$dev" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

    # enable MASQUERADE for incoming traffics
    echocmd iptables -t nat -I POSTROUTING -s "$net" ! -o "$dev" -j MASQUERADE
else
    ## enable OUTPUT: any => dev
    #echocmd iptables -I OUTPUT -o "$dev" -j ACCEPT
    #echocmd iptables -I INPUT -i "$dev" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

    # enable FORWARD: any ==> dev
    echocmd iptables -I FORWARD -o "$dev" -j ACCEPT
    echocmd iptables -I FORWARD -i "$dev" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

    # enable MASQUERADE
    echocmd iptables -t nat -I POSTROUTING -o "$dev" -j MASQUERADE
fi

# ICMP/ping
echocmd iptables -I INPUT -i "$dev" -p icmp -j ACCEPT

## IGMP
#echocmd iptables -I INPUT -i "$dev" -p igmp -j ACCEPT
## DNS/53
#echocmd iptables -I INPUT -i "$dev" -p tcp -m tcp --dport 53 -j ACCEPT
#echocmd iptables -I INPUT -i "$dev" -p udp -m udp --dport 53 -j ACCEPT
## DHCP
#echocmd iptables -I INPUT -i "$dev" -p udp -m udp --dport 67 -j ACCEPT
#echocmd iptables -I INPUT -i "$dev" -p udp -m udp --dport 68 -j ACCEPT

# enable TCPMSS
tcpmss=( -p tcp -m tcp --tcp-flags "SYN,RST" SYN -j TCPMSS --clamp-mss-to-pmtu )
echocmd iptables -t mangle -I FORWARD -o "$dev" "${tcpmss[@]}"
