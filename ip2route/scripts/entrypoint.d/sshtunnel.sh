#!/bin/bash -e
# 
# options       =
            MODE="${MODE:-basic}" # basic,route,server
     SOCKS5_PORT="${SOCKS5_PORT:-1070}"

      LOCAL_ADDR="${LOCAL_ADDR:-10.20.30.40}"
       LOCAL_TUN="${LOCAL_TUN:-0}"
         MAX_TUN="${MAX_TUN:-1}" # for server mode

     REMOTE_HOST="${REMOTE_HOST:-}" # no def value
     REMOTE_ADDR="${REMOTE_ADDR:-${LOCAL_ADDR%.*}.1}"
      REMOTE_TUN="${REMOTE_TUN:-0}"

       SSH_IDENT="${SSH_IDENT:-/config/ssh/id_ed25519}"
        SSH_OPTS="${SSH_OPTS:--v}" # user options

echocmd() {
    echo -e "--\\033[34m $(tr -s ' ' <<< "$*") \\033[0m"
    "$@"
}

options+=(
    CheckHostIP=no
    Compression=yes
    IdentityFile="$SSH_IDENT"
    BatchMode=yes
    LogLevel=VERBOSE

    TCPKeepAlive=yes                # spoofable
    ServerAliveInterval=15          # < 30s, send a null packet to server
    ServerAliveCountMax=3           # disconnect after max * interval
    ConnectTimeout=59               # wait before connectting timeout
    ConnectionAttempts=3            # attempts before stop connectting
    StrictHostKeyChecking=no        # no strict host key check
    ExitOnForwardFailure=yes        # exit if the connection cann't setup
)

[ "$MODE" = route ] && options+=(Tunnel=point-to-point) || true

# sanity check
[ "$MODE" = server ] && REMOTE_ADDR= || MAX_TUN=1

# ssh keygen if not exists
if [ -n "$REMOTE_HOST" ] && [ ! -f "$SSH_IDENT" ]; then
    echocmd mkdir -pv "$(dirname "$SSH_IDENT")"
    echocmd ssh-keygen -f "$SSH_IDENT" -t ed25519 -q -N "sshtunnel"
fi

tcpmss=( -p tcp -m tcp --tcp-flags "SYN,RST" SYN -j TCPMSS --clamp-mss-to-pmtu )

cleanup() {
    for (( i=0; i < "$MAX_TUN"; ++i )); do
        tun0="tun$((LOCAL_TUN + i))"

        IFS='./' read -r a b c d _ <<< "$LOCAL_ADDR"
        addr="$a.$b.$((c + i)).$d"

        echocmd ip tuntap del "$tun0" mode tun || true

        if [ -n "$REMOTE_ADDR" ]; then
            echocmd ip route del "$REMOTE_ADDR" || true
            echocmd ip route del "$REMOTE_ADDR" dev "$tun0" || true
            echocmd ip route del "${addr%.*}.0/24" via "$REMOTE_ADDR" || true
            echocmd ip route del "${addr%.*}.0/24" dev "$tun0" || true
            echocmd ip route del "${addr%.*}.0/24" via "$REMOTE_ADDR" dev "$tun0" || true
        fi

        echocmd ip route del "${addr%.*}.0/24" || true
        echocmd ip route del "${addr%.*}.0/24" dev "$tun0" || true
        
        # delete rules
        iptables -S | grep -Fw -- "-i $tun0" | sed 's/-A/-D/g' | xargs iptables || true
        iptables -S | grep -Fw -- "-o $tun0" | sed 's/-A/-D/g' | xargs iptables || true
        iptables -t nat -S | grep -Fw -- "-i $tun0" | sed 's/-A/-D/g' | xargs iptables -t nat || true
        iptables -t nat -S | grep -Fw -- "-o $tun0" | sed 's/-A/-D/g' | xargs iptables -t nat || true
        iptables -t mangle -S | grep -Fw -- "-i $tun0" | sed 's/-A/-D/g' | xargs iptables -t mangle || true
        iptables -t mangle -S | grep -Fw -- "-o $tun0" | sed 's/-A/-D/g' | xargs iptables -t mangle || true
    done
}

# always cleanup
[ "$MODE" = basic ] || cleanup

# cleanup explicitly
[ "$1" = cleanup ] && {
    echo -e "\n\n ==== $0 cleaned ===="
    exit 
} || true

[ "$MODE" = basic ] || {
    for (( i=0; i < "$MAX_TUN"; ++i )); do
        # setup tuntap device
        tun0="tun$((LOCAL_TUN + i))"

        # choose subnet
        IFS='./' read -r a b c d _ <<< "$LOCAL_ADDR"
        addr="$a.$b.$((c + i)).$d"

        echocmd ip tuntap add "$tun0" mode tun
        echocmd ip addr add "$addr/24" brd + dev "$tun0"
        echocmd ip link set "$tun0" up

        # 'RTNETLINK answers: File exists'
        if [ -n "$REMOTE_ADDR" ]; then
            echocmd ip route add "$REMOTE_ADDR" dev "$tun0"
            echocmd ip route add "${addr%.*}.0/24" via "$REMOTE_ADDR" || true
        else
            echocmd ip route add "${addr%.*}.0/24" dev "$tun0" || true
        fi

        if [ "$MODE" = server ]; then
            # enable FORWARD: tun0 => any
            echocmd iptables -I FORWARD -i "$tun0" -j ACCEPT
            echocmd iptables -I FORWARD -o "$tun0" -m state --state RELATED,ESTABLISHED -j ACCEPT

            # enable MASQUERADE
            echocmd iptables -t nat -I POSTROUTING -s "${addr%.*}.0/24" -j MASQUERADE
        else
            # enable FORWARD: any ==> tun0
            echocmd iptables -I FORWARD -o "$tun0" -j ACCEPT
            echocmd iptables -I FORWARD -i "$tun0" -m state --state RELATED,ESTABLISHED -j ACCEPT

            # enable MASQUERADE
            echocmd iptables -t nat -I POSTROUTING -o "$tun0" -j MASQUERADE
        fi

        # enable TCPMSS
        echocmd iptables -t mangle -I FORWARD -o "$tun0" "${tcpmss[@]}"
    done
}

if [ "$MODE" = server ]; then
    # start a sshd daemon?
    args=( -o PermitTunnel=yes )
    exit 0
fi

# do not trap in server mode
[ "$MODE" = basic ] || trap cleanup EXIT

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

echocmd ssh -nN -D "0.0.0.0:$SOCKS5_PORT" "${args[@]}" "$REMOTE_USER@$REMOTE_HOST"
