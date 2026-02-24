#!/bin/bash -e
# a pretty iptables script (c) Chen Fang 2025, mtdcy.chen@gmail.com.
#
# v0.1  20231030    initial version
# v0.2  20240120    add env VERBOSE
# v1.0  20250428    remove FORWARD and NAT codes
#
# shellcheck disable=SC2248
# shellcheck disable=SC2086
# shellcheck disable=SC2155
# shellcheck disable=SC2034

set +H
set -e

# options       =
             WAN="${WAN:-$(ip route show default | head -n1 | grep -oP 'dev \K\S+')}"
             LAN="${LAN:-$WAN}"
             NET="$(ip addr show "$LAN" | grep -oP 'inet \K\S+')"

      RULES_FILE="${RULES_FILE:-/config/afw.rules}"
         VERBOSE="${VERBOSE:-}"

# constants     =
             NEW="-m conntrack --ctstate NEW"
         TRACKED="-m conntrack --ctstate RELATED,ESTABLISHED"
       UNREPLIED="-m conntrack --ctstate UNREPLIED"
           LOCAL="-m addrtype --dst-type LOCAL"
         BRIDGED="-m physdev --physdev-is-bridged"
          TCPSYN="-p tcp --tcp-flags SYN,RST SYN"
          TCPMSS="TCPMSS --set-mss" # suffix with mss value
         COMMENT="-m comment --comment"

        iptables="${iptables:-$(which iptables)}"

usage() {
    cat <<EOF
$(basename $0) <config>
$(basename $0) COMMAND [parameters...]

Commands:
    # Filters
    ALLOW   source tcp|udp[:dports] "match"          [comments]
    BLOCK   source tcp|udp[:dports] "match"          [comments]
    DNAT    source tcp|udp[:dports] ip[:port]|TARGET [comments]

    # Logger
    IPLOG   source destination tcp|udp[:dports] "match" [label]

Targets:
    AFW     : Input filter target hook PREROUTING and INPUT chain

Constants:
    LOCAL       : match connections to local, "$LOCAL"
    TRACKED     : match related or established connections, "$TRACKED"
    BRIDGED     : match packets on bridged port, "$BRIDGED"
    TCPSYN      : match tcp SYN packets, "$TCPSYN"
    TCPMSS      : set tcp MSS value, "$TCPMSS" <value>
EOF
}

info() {
    echo -e "🚀\\033[32m $* \\033[0m🚀"
}

echocmd() {
    echo -e "--\\033[34m $* \\033[0m" >&2
    eval -- "$*"
}

# Syntax:
#   s - source
#   d - destination
#   p - protocol
#   m - match
#   j - jump
#   t - target
#   l - label

# IPTable
# IPTtmj target "match" <ACCEPT|DROP|...> [comments]
IPTtmj() {
    local rule="$1"

    [ -z "$2" ]     || rule="$rule $2"
    [ -z "$3" ]     || rule="$rule -j $3"
    [ -z "${*:4}" ] || rule="$rule -m comment --comment \"${*:4}\""

    echocmd "$iptables -A $rule"
}

# IPTp2m tcp|udp[:dports] [sports] => match-rule
#  multiports: tcp:80,443
#  port range: tcp:1000-2000
#  protocols:  tcp+udp:53
IPTp2m() {
    IFS=':' read -r proto ports <<<"$@"

    for p in ${proto//+/ }; do
        local match="-p $p"
        case "$ports" in
            "")                                                       ;;
            *,*)    match="$match -m multiport --dports $ports"       ;;
            *-*)    match="$match -m multiport --dports ${ports/-/:}" ;;
            *)      match="$match -m $p --dport $ports"               ;;
        esac
        echo "$match"
    done
}

# IPTs2m source[:sport] => match-rule
IPTs2m() {
    IFS=':' read -r source sp <<<"$@"
    [[ $source =~ ^! ]] && not="! " && source=${source#!}
    case "$source" in
        any | "*")  source="" ;;
        *.*.*.*)    source="-s $source" ;;
        *)          source="-i $source" ;;
    esac

    [ -z "$sp" ] || source="$source -m multiport --sports $sp"
    echo "$not$source"
}

# IPTd2m destination[:dport] => match-rule
IPTd2m() {
    IFS=':' read -r dest dp <<<"$@"
    [[ $dest =~ ^! ]] && not="! " && dest=${dest#!}
    case "$dest" in
        any | "*")  dest="" ;;
        *.*.*.*)    dest="-d $dest" ;;
        *)          dest="-o $dest" ;;
    esac

    if [ -z "$dp" ]; then
        echo "$not$dest"
    else
        while read -r match; do
            echo "$not$dest $match"
        done < <( IPTp2m "tcp+udp:$dp" )
    fi
}

# ==============================================================================
# =============================== IPtable Filter ===============================
# IPFsmj source "match" TARGET [comments]
IPFsmj() {
    local match="$(IPTs2m "$1")"
    [ -z "$2" ] || match="$match $2"
    case "$3" in
        DNAT*)  IPTtmj "AFW -t nat" "${match# }" "$3" "${@:4}" ;;
        *)      IPTtmj "AFW -t nat"  "${match# }" "$3" "${@:4}" ;;
    esac
}

# IPFspmj source tcp|udp[:dports] "match" TARGET [comments]
IPFspmj() {
    while read -r match; do
        [ -z "$3" ] || match="$match $3"
        IPFsmj "$1" "${match# }" "$4" "${@:5}"
    done < <( IPTp2m "$2" )
}

# ==============================================================================
# BLOCK Input Traffics
# BLOCK source tcp|udp[:dports] "match" [comments]
BLOCK() {
    case "$3" in
        *-j*)   IPFspmj "$1" "$2" "$3" ""    "${@:4}" ;;
        *)      IPFspmj "$1" "$2" "$3" BLOCK "${@:4}" ;;
    esac
}

# ALLOW Input Traffics
# ALLOW source tcp|udp[:dports] "match" [comments]
ALLOW() {
    case "$3" in
        *-j*)   IPFspmj "$1" "$2" "$3" ""     "${@:4}" ;;
        *)      IPFspmj "$1" "$2" "$3" ACCEPT "${@:4}" ;;
    esac
}

# REJECT Forward Traffics
# REJECT source destination[:dports] "match" [comments]
REJECT() {
    while read -r match; do
        case "$3" in
            *-j*)   IPFsmj "$1" "$match $3" ""    "${@:4}" ;;
            *)      IPFsmj "$1" "$match $3" BLOCK "${@:4}" ;;
        esac
    done < <( IPTd2m "$2" )
}

# Docker compatible
# DOCKER source tcp|udp[:dports] "match" [comments]
DOCKER() {
    case "$3" in
        *-j*)   IPFspmj "$1" "$2" "$3" ""     "${@:4}" ;;
        *)      IPFspmj "$1" "$2" "$3" DOCKER "${@:4}" ;;
    esac
}

# DNAT source tcp|udp:dports ip[:port]|TARGET [comments]
DNAT() {
    case "$3" in
        *.*.*.*) IPFspmj "$1" "$2" "" "DNAT --to $3" "${@:4}" ;;
        *)       IPFspmj "$1" "$2" "" "$3"           "${@:4}" ;;
    esac
}

# SNAT destination tcp|udp:dports "ip|TARGET" [comments]
SNAT() {
    while read -r match; do
        match="-o $LAN $(IPTd2m $1) $match"
        case "$3" in
            ^*.*.*.*)   IPTtmj "POSTROUTING -t nat" "${match# }" "SNAT --to $3" "${@:4}" ;;
            "")         IPTtmj "POSTROUTING -t nat" "${match# }" "MASQUERADE"   "${@:4}" ;;
            *)          IPTtmj "POSTROUTING -t nat" "${match# }" "$4"           "${@:4}" ;;
        esac
    done < <(IPTp2m $2)
}

# ==============================================================================
# IPtable Logger
# IPLtmj target "match" "prefix"
IPLtmj() {
    local rule=("$1")

    [ -z "$2" ] || rule+=("$2")
                   rule+=("-j LOG")
    [ -z "$3" ] || rule+=("--log-prefix 'LOG:$3 => '")

    # always insert
    echocmd "$iptables -I ${rule[*]}"
}

# IPLOG source destination tcp|udp[:dports] "match" [label]
IPLOG() {
    local match=("$(IPTs2m $1)")
    [ -z "$4" ] || match+=("$4")
    while read -r m; do
        match+=("$m")
        while read -r m; do
            IPLtmj AFW "${match[*]} $m" "$5"
        done < <( IPTp2m "$3" )
    done < <( IPTd2m "$2" )
}

# CLEAN interface
FLUSH() {
    while read -r line; do
        echocmd "$iptables -t nat ${line/-A/-D}"
    done < <($iptables -t nat -S | grep -Ew -- "-i $1|-o $1")

    while read -r line; do
        echocmd "$iptables ${line/-A/-D}"
    done < <($iptables -S | grep -Ew -- "-i $1|-o $1")
}

[ "$1" = "help" ] && usage && exit

# always run as root
[ "$(id -u)" -ne 0 ] && exec sudo VERBOSE=$VERBOSE "$0" "$@"

# ==============================================================================
# init PREROUTING for DNAT & firewall

# cleanup
FLUSH "$WAN"
[ "$LAN" = "$WAN" ] || FLUSH "$LAN"

info "prepare BLOCK TARGET"
echocmd "$iptables -t nat -N BLOCK" || echocmd "$iptables -t nat -F BLOCK"
[ -z "$VERBOSE" ] || echocmd "$iptables -t nat -A BLOCK -j LOG --log-prefix 'BLOCK => '"
echocmd "$iptables -t nat -A BLOCK -j DNAT --to-destination 0.0.0.1"

info "prepare PREROUTING/AFW" 
echocmd "$iptables -t nat -N AFW" || echocmd "$iptables -t nat -F AFW"
# WAN => AFW
echocmd "$iptables -t nat -I PREROUTING -i $WAN $LOCAL -j AFW"
# LAN => ACCEPT
[ "$LAN" = "$WAN" ] || echocmd "$iptables -t nat -I PREROUTING -i $LAN $LOCAL -j ACCEPT"

info "prepare FORWARD/AFW"
echocmd "$iptables -N AFW" || echocmd "$iptables -F AFW"
# accept tracked connections
echocmd "$iptables -A AFW $TRACKED -j ACCEPT"
# https://serverfault.com/questions/157375/reject-vs-drop-when-using-iptables
echocmd "$iptables -A AFW -d 0.0.0.1/32 -p tcp -j REJECT --reject-with tcp-reset"
#echocmd "$iptables -A AFW -d 0.0.0.1/32 -p udp -j REJECT --reject-with icmp-port-unreachable"
echocmd "$iptables -A AFW -d 0.0.0.1/32 -j DROP"
echocmd "$iptables -A AFW -j ACCEPT" # in case FORWARD in DROP policy

echocmd "$iptables -P FORWARD ACCEPT" # force ACCEPT policy
echocmd "$iptables -I FORWARD -i $WAN ! -s $NET -j AFW $COMMENT 'WAN'"              #2. WAN => AFW 
echocmd "$iptables -I FORWARD -i $LAN -s $NET -j ACCEPT $COMMENT 'LAN'"             #1. LAN

if [ -f "$RULES_FILE" ]; then
    info "apply rules $RULES_FILE"
    source "$RULES_FILE"
else
    echocmd "$iptables -t nat -A AFW -j RETURN $COMMENT 'no afw rules'"
    info "no afw rules, exit"
    exit
fi

info "postproc PREROUTING/AFW"
echocmd "$iptables -t nat -A AFW -s $NET -j ACCEPT $COMMENT 'Allow/Local'"          # allow local traffics
echocmd "$iptables -t nat -A AFW -j BLOCK $COMMENT 'Block/All'"                     # block all

info "enable NAT loopback"
echocmd "$iptables -t nat -I POSTROUTING -s $NET -d $NET -o $LAN -m addrtype ! --src-type LOCAL -j MASQUERADE $COMMENT 'NAT loopback'"

if [ "$LAN" != "$WAN" ]; then
    info "enable MASQUERADE"
    echocmd "$iptables -t nat -I POSTROUTING -o $WAN -j MASQUERADE $COMMENT 'WAN/NAT'"
fi

echocmd "$iptables -t nat -vnL PREROUTING"
echocmd "$iptables -t nat -vnL AFW"
