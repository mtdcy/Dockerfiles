#!/bin/bash -e
# 
# options       =
            MODE="${MODE:-basic}" # basic,route,serve
     SOCKS5_PORT="${SOCKS5_PORT:-1070}"

      LOCAL_ADDR="${LOCAL_ADDR:-10.20.30.40}"
       LOCAL_TUN="${LOCAL_TUN:-0}"
         MAX_TUN="${MAX_TUN:-1}" # for serve mode

     REMOTE_HOST="${REMOTE_HOST:-}" # no def value
     REMOTE_ADDR="${REMOTE_ADDR:-${LOCAL_ADDR%.*}.1}"
      REMOTE_TUN="${REMOTE_TUN:-0}"

       SSH_IDENT="${SSH_IDENT:-/config/ssh/id_ed25519}"
        SSH_OPTS="${SSH_OPTS:--v}" # user options
     SSH_LOGFILE="${SSH_LOGFILE:-/config/sshtunnel.log}"

set +H 

info() {
    echo -e "🚀\\033[32m $* \\033[0m🚀"
}

echocmd() {
    echo -e "--\\033[34m $* \\033[0m"
    "$@"
}

options+=(
    IdentityFile="$SSH_IDENT"
    #BatchMode=yes
    LogLevel=VERBOSE

    CheckHostIP=no                  #
    Compression=yes                 # Compression
    TCPKeepAlive=yes                # spoofable
    ServerAliveInterval=15          # < 30s, send a null packet to server
    ServerAliveCountMax=3           # disconnect after max * interval
    ConnectTimeout=30               # wait before connectting timeout
    ConnectionAttempts=3            # attempts before stop connectting
    StrictHostKeyChecking=no        # no strict host key check
    ExitOnForwardFailure=yes        # exit if the connection cann't setup
)

[ "$MODE" = route ] && options+=(Tunnel=point-to-point) || true

# sanity check
[ "$MODE" = serve ] && REMOTE_ADDR= || MAX_TUN=1

# ssh keygen if not exists
if [ -n "$REMOTE_HOST" ] && [ ! -f "$SSH_IDENT" ]; then
    echocmd mkdir -pv "$(dirname "$SSH_IDENT")"
    echocmd ssh-keygen -f "$SSH_IDENT" -t ed25519 -q -N "sshtunnel"
fi

# flush <tun0> [-t table]
flush() {
    while read -r rule; do
        [ -n "$rule" ] || continue
        echocmd iptables "${@:2}" ${rule/-A/-D} || true
    done < <(iptables -S "${@:2}" | grep -E -- "-i $1|-o $1")
}

cleanup() {
    for (( i=0; i < "$MAX_TUN"; ++i )); do
        tun0="tun$((LOCAL_TUN + i))"

        IFS='./' read -r a b c d _ <<< "$LOCAL_ADDR"
        addr="$a.$b.$((c + i)).$d"

        echocmd ip tuntap del "$tun0" mode tun || true

        echocmd ip route del "${addr%.*}.0/24" || true
        
        [ -z "$REMOTE_ADDR" ] || echocmd ip route del "$REMOTE_ADDR" || true
        
        # delete rules
        flush "$tun0"
        flush "$tun0" -t nat
        flush "$tun0" -t mangle
    done
}

# always cleanup
[ "$MODE" = basic ] || cleanup

# cleanup explicitly
[ "$1" = cleanup ] && {
    info "ssh tunnel cleaned"
    exit 
} || true

[ "$MODE" = basic ] || {
    for (( i=0; i < "$MAX_TUN"; ++i )); do
        # setup tuntap device
        tun0="tun$((LOCAL_TUN + i))"

        # choose subnet
        IFS='./' read -r a b c d _ <<< "$LOCAL_ADDR"
        addr="$a.$b.$((c + i)).$d"

        # fails if "$tun0" is in use
        echocmd ip tuntap add "$tun0" mode tun || true
        echocmd ip addr add "$addr/24" brd + dev "$tun0" || true
        echocmd ip link set "$tun0" up || true

        # 'RTNETLINK answers: File exists'
        if [ -n "$REMOTE_ADDR" ]; then
            echocmd ip route add "$REMOTE_ADDR" dev "$tun0"
            echocmd ip route add "${addr%.*}.0/24" via "$REMOTE_ADDR" || true
        else
            echocmd ip route add "${addr%.*}.0/24" dev "$tun0" || true
        fi

        if [ "$MODE" = serve ]; then
            # enable INPUT & OUTPUT
            echocmd iptables -I OUTPUT -o "$tun0" -j ACCEPT
            echocmd iptables -I INPUT -i "$tun0" -j ACCEPT

            # enable FORWARD: tun0 => any
            echocmd iptables -I FORWARD -i "$tun0" -j ACCEPT
            echocmd iptables -I FORWARD -o "$tun0" -m state --state RELATED,ESTABLISHED -j ACCEPT

            # enable MASQUERADE for incoming traffics
            echocmd iptables -t nat -I POSTROUTING -s "${addr%.*}.0/24" ! -o "$tun0" -j MASQUERADE
        else
            # enable OUTPUT: any => tun0
            echocmd iptables -I OUTPUT -o "$tun0" -j ACCEPT
            echocmd iptables -I INPUT -i "$tun0" -m state --state RELATED,ESTABLISHED -j ACCEPT

            # enable FORWARD: any ==> tun0
            echocmd iptables -I FORWARD -o "$tun0" -j ACCEPT
            echocmd iptables -I FORWARD -i "$tun0" -m state --state RELATED,ESTABLISHED -j ACCEPT

            # enable MASQUERADE
            echocmd iptables -t nat -I POSTROUTING -o "$tun0" -j MASQUERADE
        fi

        # ICMP/ping
        echocmd iptables -I INPUT -i "$tun0" -p icmp -j ACCEPT
        # IGMP
        echocmd iptables -I INPUT -i "$tun0" -p igmp -j ACCEPT
        # DNS/53
        echocmd iptables -I INPUT -i "$tun0" -p tcp -m tcp --dport 53 -j ACCEPT
        echocmd iptables -I INPUT -i "$tun0" -p udp -m udp --dport 53 -j ACCEPT
        # DHCP
        echocmd iptables -I INPUT -i "$tun0" -p udp -m udp --dport 67 -j ACCEPT
        echocmd iptables -I INPUT -i "$tun0" -p udp -m udp --dport 68 -j ACCEPT

        # enable TCPMSS
        tcpmss=( -p tcp -m tcp --tcp-flags "SYN,RST" SYN -j TCPMSS --clamp-mss-to-pmtu )
        echocmd iptables -t mangle -I FORWARD -o "$tun0" "${tcpmss[@]}"
    done
}

if [ "$MODE" = serve ]; then
    # start a sshd daemon?
    args=( -o PermitTunnel=yes )
    exit 0
fi

# no default config file
args=(-F none)

# ssh options to args
for x in "${options[@]}"; do
    [ -z "$x" ] || args+=(-o "$x")
done

[ "$MODE" = route ] && args+=( -w "$LOCAL_TUN:${REMOTE_TUN:-0}" ) || true

# apply user options
[ -z "$*" ] || args+=("$@")
[ -z "${SSH_OPTS[*]}" ] || args+=("${SSH_OPTS[@]}")

# apply host settings
IFS='@:' read -r REMOTE_USER REMOTE_HOST REMOTE_PORT <<< "$REMOTE_HOST"
[ -z "$REMOTE_PORT" ] || args+=( -p "$REMOTE_PORT" )

sshc=( ssh -nN -D "0.0.0.0:$SOCKS5_PORT" "${args[@]}" "$REMOTE_USER@$REMOTE_HOST" )

# do not block
info "${sshc[*]}"
"${sshc[@]}" 2>&1 | ts "[%b %d %H:%M:%S]" | tee -a "$SSH_LOGFILE" & disown
