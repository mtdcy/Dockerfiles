#!/bin/bash -e
# 
# iptables.sh tun0 [gw]
# iptables.sh flush tun0

set +H # for !

iptables="${iptables:-$(which iptables)}"

echocmd() {
    echo -e "--\\033[34m $* \\033[0m" >&2
    "$@"
}

# flush <dev> [-t table]
delete() {
    while read -r rule; do
        [ -n "$rule" ] || continue
        echocmd "$iptables" "${@:2}" ${rule/-A/-D} || true
    done < <("$iptables" -S "${@:2}" | grep -E -- "-i $1|-o $1")
}

# flush <dev>
flush() {
    delete "$1" || true
    delete "$1" -t nat || true
    delete "$1" -t mangle || true
   
    echocmd ip route flush dev "$1" || true
}

case "$1" in
    flush)
        flush "$2" || true
        exit
        ;;
esac

# ip
dev="$1"
net="$2"
ngw="$3"

flush "$dev"
if [ -z "$net" ]; then
    net="$(ip addr show "$dev" | grep -oP 'inet \K\S+')"
else
    echocmd ip addr flush dev "$1" || true
    echocmd ip addr add "$net" brd + dev "$dev"
    echocmd ip link set "$dev" up
fi

[[ "$net" =~ / ]] || net="$net/24"

# ip to net
net="$(ipcalc-ng "$net" | grep -Fw 'Network:' | cut -f2)"

# 'RTNETLINK answers: File exists'
if [ -n "$ngw" ]; then
    # Error: Nexthop has invalid gateway.
    echocmd ip route add "$net" via "$ngw" dev "$dev" proto static onlink || 
    # RTNETLINK answers: File exists
    echocmd ip route rep "$net" via "$ngw" dev "$dev" proto static onlink || {
        echocmd ip route add "$ngw" dev "$dev" proto static
        # RTNETLINK answers: File exists
        echocmd ip route add "$net" via "$ngw" proto static ||
        echocmd ip route rep "$net" via "$ngw" proto static
    }
    
    ## enable OUTPUT: any => dev
    echocmd "$iptables" -I OUTPUT -o "$dev" -j ACCEPT
    echocmd "$iptables" -I INPUT -i "$dev" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

    # enable FORWARD: any ==> dev
    echocmd "$iptables" -I FORWARD -o "$dev" -j ACCEPT
    echocmd "$iptables" -I FORWARD -i "$dev" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    echocmd "$iptables" -I FORWARD -i "$dev" -s "$net" -j ACCEPT # allow traffics from other edge

    # enable output MASQUERADE
    echocmd "$iptables" -t nat -I POSTROUTING -o "$dev" -j MASQUERADE
    
    # enable input MASQUERADE
    echocmd "$iptables" -t nat -I POSTROUTING -s "$net" ! -o "$dev" -j MASQUERADE
else
    echocmd ip route add "$net" dev "$dev" proto static ||
    echocmd ip route rep "$net" dev "$dev" proto static
    
    ## enable INPUT & OUTPUT
    echocmd "$iptables" -I OUTPUT -o "$dev" -j ACCEPT
    echocmd "$iptables" -I INPUT -i "$dev" -j ACCEPT

    # enable FORWARD: dev => any
    echocmd "$iptables" -I FORWARD -i "$dev" -j ACCEPT
    echocmd "$iptables" -I FORWARD -o "$dev" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    echocmd "$iptables" -I FORWARD -o "$dev" -s "$net" -j ACCEPT # allow traffics from other edge
  
    # no output MASQUERADE: keep visit ip
    
    # enable input MASQUERADE
    echocmd "$iptables" -t nat -I POSTROUTING -s "$net" ! -o "$dev" -j MASQUERADE
fi

# ICMP/ping
echocmd "$iptables" -I INPUT -i "$dev" -p icmp -j ACCEPT
# IGMP
echocmd "$iptables" -I INPUT -i "$dev" -p igmp -j ACCEPT
# DNS/53
echocmd "$iptables" -I INPUT -i "$dev" -p tcp -m tcp --dport 53 -j ACCEPT
echocmd "$iptables" -I INPUT -i "$dev" -p udp -m udp --dport 53 -j ACCEPT
## DHCP
#echocmd "$iptables" -I INPUT -i "$dev" -p udp -m udp --dport 67 -j ACCEPT
#echocmd "$iptables" -I INPUT -i "$dev" -p udp -m udp --dport 68 -j ACCEPT

# enable TCPMSS
tcpmss=( -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu )
echocmd "$iptables" -t mangle -I FORWARD -o "$dev" "${tcpmss[@]}"
