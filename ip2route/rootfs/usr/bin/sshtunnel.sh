#!/bin/bash -e
# 
# options       =
            MODE="${MODE:-socks5}" # server,route,socks5
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

if [ "$MODE" != socks5 ]; then
    for (( i=0; i < "$MAX_TUN"; ++i )); do
        # setup tuntap device
        tun0="tun$((LOCAL_TUN + i))"

        # choose subnet
        IFS='./' read -r a b c d _ <<< "$LOCAL_ADDR"
        addr="$a.$b.$((c + i)).$d"

        echocmd ip link show "$tun0" || 
        echocmd ip tuntap add "$tun0" mode tun

        echocmd ip addr flush dev "$tun0" || true
        echocmd ip addr add "$addr/24" brd + dev "$tun0"

        echocmd ip link set "$tun0" up

        echocmd ip route del "${addr%.*}.0/24" || true
        
        # 'RTNETLINK answers: File exists'
        if [ -n "$REMOTE_ADDR" ]; then
            echocmd ip route del "$REMOTE_ADDR" || true 
            echocmd ip route add "$REMOTE_ADDR" dev "$tun0"

            echocmd ip route add "${addr%.*}.0/24" via "$REMOTE_ADDR" || true
        else
            echocmd ip route add "${addr%.*}.0/24" dev "$tun0" || true
        fi

        if [ "$MODE" = server ]; then
            # enable FORWARD: tun0 => any
            iptables -C FORWARD -i "$tun0" -j ACCEPT 2>/dev/null ||
            echocmd iptables -I FORWARD -i "$tun0" -j ACCEPT

            iptables -C FORWARD -o "$tun0" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null ||
            echocmd iptables -I FORWARD -o "$tun0" -m state --state RELATED,ESTABLISHED -j ACCEPT

            # enable MASQUERADE
            iptables -t nat -C POSTROUTING -s "${addr%.*}.0/24" -j MASQUERADE 2>/dev/null ||
            echocmd iptables -t nat -I POSTROUTING -s "${addr%.*}.0/24" -j MASQUERADE
        else
            # enable FORWARD: any ==> tun0
            iptables -C FORWARD -o "$tun0" -j ACCEPT 2>/dev/null ||
            echocmd iptables -I FORWARD -o "$tun0" -j ACCEPT

            iptables -C FORWARD -i "$tun0" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null ||
            echocmd iptables -I FORWARD -i "$tun0" -m state --state RELATED,ESTABLISHED -j ACCEPT

            # enable MASQUERADE
            iptables -t nat -C POSTROUTING -o "$tun0" -j MASQUERADE 2>/dev/null ||
            echocmd iptables -t nat -I POSTROUTING -o "$tun0" -j MASQUERADE
        fi

        # enable TCPMSS
        tcpmss=( -p tcp -m tcp --tcp-flags "SYN,RST" SYN -j TCPMSS --clamp-mss-to-pmtu )
        iptables -t mangle -C FORWARD -o "$tun0" "${tcpmss[@]}" 2>/dev/null ||
        echocmd iptables -t mangle -I FORWARD -o "$tun0" "${tcpmss[@]}"
    done
fi

if [ "$MODE" = server ]; then
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

echocmd ssh -nN -D "0.0.0.0:$SOCKS5_PORT" "${args[@]}" "$REMOTE_USER@$REMOTE_HOST"
