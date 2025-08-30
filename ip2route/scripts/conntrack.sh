#!/bin/bash
# A pretty network connection track script.
# Copyright (c) Chen Fang 2023, mtdcy.chen@gmail.com.
#
# shellcheck disable=SC2046
# shellcheck disable=SC2086

set -e

usage() {
    cat << EOF
A pretty network connection track script.
Copyright (c) Chen Fang 2023, mtdcy.chen@gmail.com.

Usage: $(basename $0) [options] [host]

Examples:

    1. $(basename $0)                   - view all connections
    2. $(basename $0) 192.168.0.2       - view connections from/to 192.168.0.2
    3. $(basename $0) 192.168.0.0/24    - view connections from/to 192.168.0.0/24
    4. $(basename $0) github.com        - view connections from/to github.com
EOF
}

W4=21   # width for ipv4:port
W6=45   # width for ipv6:port

WI=$W4
format_lines() {
    while read -r line; do
        [ -z "$line" ] && continue

        #echo -e "\n = $line"
        # proto proto_number ...
        IFS=' ' read -r proto _ conn <<< "$line"

        # the live time may missing
        [[ "$conn" =~ ^[0-9]+ ]] && IFS=' ' read -r _ conn <<< "$conn"

        state=""
        [[ "$conn" =~ ^[A-Z]+ ]] && IFS=' ' read -r state conn <<< "$conn"

        # connection source => destination
        case "$proto" in
            tcp|udp)
                IFS=' =' read -r _ src _ dst _ sp _ dp conn <<< "$conn"
                printf " %-7.7s %-${WI}s => %-${WI}s" "$proto" "$src:$sp" "$dst:$dp"
                ;;
            *)
                IFS=' =' read -r _ src _ dst _ _ _ conn <<< "$conn"
                printf " %-7.7s %-${WI}s => %-${WI}s" "$proto" "$dst" "$src"
                ;;
        esac

        # packets=n bytes=n
        #  => sysctl -w net.netfilter.nf_conntrack_acct=1
        [[ "$conn" =~ ^packets=         ]] && IFS=' ' read -r _ conn <<< "$conn"
        [[ "$conn" =~ ^bytes=           ]] && IFS=' =' read -r _ bytes conn <<< "$conn"
        # [UNREPLIED]
        [[ "$conn" =~ ^\[UNREPLIED\]    ]] && IFS=' ' read -r _ conn <<< "$conn" && state="UNREPLIED"

        if [ ! -z "$bytes" ]; then
            # shortten states: E - ESTABLISHED, T - TIME_WAIT, S - SYN_SENT, U - UNREPLIED
            printf ' %7s' $(numfmt --to iec "$bytes")
            [ ! -z "$state" ] && printf ' [%-.1s]' "$state"
        else
            printf ' %11s' "$state"
        fi

        # reply source => destination
        IFS=' =' read -r _ reply_src _ reply_dst conn <<< "$conn"
        case "$proto" in
            tcp|udp)
                IFS=' =' read -r _ rsp _ rdp conn <<< "$conn"
                ;;
            *)
                IFS=' ' read -r _ _ _ conn <<< "$conn"
                ;;
        esac

        if [ "$dst" = "$reply_dst" -a "$src" != "$reply_src" ] ||
           [ "$src" = "$reply_dst" -a "$dst" != "$reply_src" ]; then
            # > next hop
            [ ! -z "$rsp" ] && echo -ne " \t>$reply_src:$rsp" || echo -ne " \t>$reply_src"
        elif [ "$dst" = "$reply_src" -a "$src" != "$reply_dst" ]; then
            # @ gateway
            [ ! -z "$rdp" ] && echo -ne " \t@$reply_dst:$rdp" || echo -ne " \t@$reply_dst"
        fi

        echo ""
    done
}

[ "$1" = "help" ] && { usage; exit 0; }

[ $(id -u) -ne 0 ] && exec sudo "$0" "$@"

which -s dig || apt install dnsutils
which -s conntrack || apt install conntrack

host="$1"
IPv4="^([0-9]{1,3}\.){3}([0-9]{1,3}){1}"
IPv6="^([0-9a-fA-F]{0,4}:)+([0-9a-fA-F]{0,4}){1}"

if [[ $host =~ $IPv4 ]]; then
    host4=$host
elif [[ $host =~ $IPv6 ]]; then
    host6=$host
elif [ ! -z "$host" ]; then
    host4=$(dig +short $host A 2> /dev/null | grep -v '\.$' || true)
    host6=$(dig +short $host AAAA 2> /dev/null | grep -v '\.$' || true)
    echo -e " #$host => |${host4//$'\n'/;}|${host6//$'\n'/;}|\n"
fi

if [ -n "$host4" ] || [ -z "$host" ]; then
    echo " # IPv4"
    WI=$W4
    printf " %-7s %-${WI}s => %-${WI}s %11s \t%s\n" "proto" "source" "destition" "state" ">next | @gw"
    if [ -z "$host" ]; then
        conntrack -f ipv4 -L 2> /dev/null || true               # list all
    else
        while read -r line; do
            conntrack -f ipv4 -L -s $line || true   # match source
            conntrack -f ipv4 -L -d $line || true   # match destination
            #conntrack -f ipv4 -L -r $line || true   # match reply source
            #conntrack -f ipv4 -L -q $line || true   # match reply destination
        done <<< "$host4"
    fi 2>/dev/null | grep -v "127.0.0.1" | format_lines
    echo ""
fi

if [ -n "$host6" ] || [ -z "$host" ]; then
    echo " # IPv6"
    WI=$W6
    printf " %-7s %-${WI}s => %-${WI}s %11s \t%s\n" "proto" "source" "destition" "state" ">next | @gw"
    if [ -z "$host" ]; then
        conntrack -f ipv6 -L 2> /dev/null || true               # list all
    else
        while read -r line; do
            conntrack -f ipv6 -L -s $line || true   # match source
            conntrack -f ipv6 -L -d $line || true   # match destination
            #conntrack -f ipv6 -L -r $line || true   # match reply source
            #conntrack -f ipv6 -L -q $line || true   # match reply destination
        done <<< "$host6"
    fi 2>/dev/null | grep -v "::1" | format_lines
    echo ""
fi
