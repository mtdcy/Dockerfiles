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
             NET="${NET:-$(ip addr show "$WAN" | grep -oP 'inet \K\S+')}"

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

            IPFT="-t nat"
             ipt="iptables" # IPtable Filter Table

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
    AFW-IPF     : Input filter target hook PREROUTING and INPUT chain
    AFW-DROP    : LOG and DROP target in 'filter' and 'nat' tables

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

    eval -- "$ipt -C $rule" 2>/dev/null ||
    echocmd "$ipt -A $rule"
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

    [ -z "$dp" ]    || dest="$dest -m multiport --dports $dp"
    echo "$not$dest"
}

# ==============================================================================
# =============================== IPtable Filter ===============================
# IPFsmj source "match" TARGET [comments]
IPFsmj() {
    local match="$(IPTs2m "$1")"
    [ -z "$2" ] || match="$match $2"
    case "$3" in
        DNAT*)  IPTtmj "AFW-IPF -t nat" "${match# }" "$3" "${@:4}" ;;
        *)      IPTtmj "AFW-IPF $IPFT"  "${match# }" "$3" "${@:4}" ;;
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
        *-j*)   IPFspmj "$1" "$2" "$3" ""       "${@:4}" ;;
        *)      IPFspmj "$1" "$2" "$3" AFW-DROP "${@:4}" ;;
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

# RETURN source tcp|udp[:dports] "match" [comments]
RETURN() {
    case "$3" in
        *-j*)   IPFspmj "$1" "$2" "$3" ""     "${@:4}" ;;
        *)      IPFspmj "$1" "$2" "$3" RETURN "${@:4}" ;;
    esac
}

# DNAT source tcp|udp:dports ip[:port]|TARGET [comments]
DNAT() {
    case "$3" in
        *.*.*.*) IPFspmj "$1" "$2" "" "DNAT --to $3" "${@:4}" ;;
        *)       IPFspmj "$1" "$2" "" "$3"           "${@:4}" ;;
    esac
}

# IPLtml target tcp|udp[:dports] "match" "label"
IPLtpm() {
    while read -r match; do
        [ -z "$3" ] || match="$match $3"
        IPTtmj "$1" "$match" "LOG --log-prefix \"$4: \"" "$4"
    done <<< "$(IPTp2m $2)"
}

# ==============================================================================
# IPtable Logger
# IPLOG source destination tcp|udp[:dports] "match" [label]
IPLOG() {
    local match="$(IPTs2m $1) $(IPTd2m $2) $4"
    [ -z "$4" ] || match="$match $4"

    while read -r m; do
        IPTtmj "AFW-LOG $IPFT" "$match $m" "LOG --log-prefix 'LOG:$5 => '"
    done <<< "$(IPTp2m $3)"
}

[ "$1" = "help" ] && usage && exit

# always run as root
[ "$(id -u)" -ne 0 ] && exec sudo VERBOSE=$VERBOSE "$0" "$@"

# ==============================================================================
# init PREROUTING for DNAT & firewall

info "init AFW-IPF"
while read -r line; do
    echocmd "$ipt $IPFT ${line/-A/-D}"
done < <($ipt $IPFT -S PREROUTING | grep -Fw -- "-i $WAN")
echocmd "$ipt $IPFT -N AFW-IPF" ||
echocmd "$ipt $IPFT -F AFW-IPF"
echocmd "$ipt $IPFT -I PREROUTING -i $WAN $LOCAL -j AFW-IPF"

info "init AFW-LOG"
echocmd "$ipt $IPFT -N AFW-LOG" ||
echocmd "$ipt $IPFT -F AFW-LOG"
echocmd "$ipt $IPFT -I PREROUTING -i $WAN -j AFW-LOG"

info "init AFW-DROP"
echocmd "$ipt $IPFT -N AFW-DROP" ||
echocmd "$ipt $IPFT -F AFW-DROP"
echocmd "$ipt $IPFT -A AFW-DROP -j DNAT --to-destination 0.0.0.1"

[ -z "$VERBOSE" ] || echocmd "$ipt $IPFT -I AFW-DROP -j LOG --log-prefix 'DROP => '"

while read -r line; do
    echocmd "$ipt ${line/-A/-D}"
done < <($ipt -S FORWARD | grep -Fw -- "-d 0.0.0.1")
echocmd "$ipt -I FORWARD -d 0.0.0.1/32 -j DROP -m comment --comment 'Black Hole'"

[ -f "$RULES_FILE" ] || {
    info "no afw rules, exit"
    exit
}

source "$RULES_FILE"

echocmd "$ipt -t nat -vnL PREROUTING"
echocmd "$ipt -t nat -vnL AFW-LOG"
echocmd "$ipt -t nat -vnL AFW-IPF"
echocmd "$ipt -t nat -vnL AFW-DROP"
