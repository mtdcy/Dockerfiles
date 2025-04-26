#!/bin/bash -e
# 
# options       =
            MODE="${MODE:-basic}" # basic,route,serve
     SOCKS5_PORT="${SOCKS5_PORT:-1070}"

     REMOTE_HOST="${REMOTE_HOST:-}" # no def value
        SSH_ADDR="${SSH_ADDR:-10.20.30.40/24}"
      SSH_REMOTE="${SSH_REMOTE:-${SSH_ADDR%.*}.1}"

       SSH_COUNT="${SSH_COUNT:-1}" # for serve mode
         SSH_TUN="${SSH_TUN:-tun}"
  SSH_TUN_REMOTE="${SSH_TUN_REMOTE:-$SSH_TUN}"

       SSH_IDENT="${SSH_IDENT:-/config/ssh/id_ed25519}"
     SSH_LOGFILE="${SSH_LOGFILE:-/var/log/sshtunnel.log}"
        SSH_OPTS="${SSH_OPTS:--v}" # user options

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
[ "$MODE" = serve ] && SSH_REMOTE= || SSH_COUNT=1

# ssh keygen if not exists
if [ -n "$REMOTE_HOST" ] && [ ! -f "$SSH_IDENT" ]; then
    echocmd mkdir -pv "$(dirname "$SSH_IDENT")"
    echocmd ssh-keygen -f "$SSH_IDENT" -t ed25519 -q -N "sshtunnel"
fi

clean() {
    for (( i=0; i < "$SSH_COUNT"; ++i )); do
        tun="tun$((${SSH_TUN#tun} + i))"
        info "clean ssh tunnel $tun"

        echocmd /entrypoint.d/iptables.sh flush "$tun"

        echocmd ip tuntap del "$tun" mode tun || true
    done
}

# always clean
[ "$MODE" = basic ] || clean

# clean explicitly
[ "$1" = clean ] && {
    info "ssh tunnel cleaned"
    exit 
} || true

[ "$MODE" = basic ] || {
    # check net mask
    [[ "$SSH_ADDR" =~ / ]] || SSH_ADDR="$SSH_ADDR/24"

    for (( i=0; i < "$SSH_COUNT"; ++i )); do
        # setup tuntap device
        tun="tun$((${SSH_TUN#tun} + i))"

        # choose subnet
        IFS='./' read -r a b c d _ <<< "$SSH_ADDR"
        addr="$a.$b.$((c + i)).$d"
        
        info "init ssh tunnel @$tun - $addr"

        # fails if "$tun" is in use
        echocmd ip tuntap add "$tun" mode tun || true

        echocmd /entrypoint.d/iptables.sh "$tun" "$addr/24" "$SSH_REMOTE"
    done
}

if [ "$MODE" = serve ]; then
    # start a sshd daemon?
    args=( -o PermitTunnel=yes )
    exit 0
fi

info "init ssh socks @$SSH_TUN"

# no default config file
args=(-F none)

# ssh options to args
for x in "${options[@]}"; do
    [ -z "$x" ] || args+=(-o "$x")
done

[ "$MODE" = route ] && args+=( -w "${SSH_TUN#tun}:${SSH_TUN_REMOTE#tun}" ) || true

# apply user options
[ -z "$*" ] || args+=("$@")
[ -z "${SSH_OPTS[*]}" ] || args+=("${SSH_OPTS[@]}")

# apply host settings
IFS='@:' read -r REMOTE_USER REMOTE_HOST REMOTE_PORT <<< "${REMOTE_HOST#*//}"
[ -z "$REMOTE_PORT" ] || args+=( -p "$REMOTE_PORT" )

sshc=( ssh -nN -D "0.0.0.0:$SOCKS5_PORT" "${args[@]}" "$REMOTE_USER@$REMOTE_HOST" )

# do not block
info "${sshc[*]}"
"${sshc[@]}" 2>&1 | ts "[%b %d %H:%M:%S]" | tee -a "$SSH_LOGFILE" & disown
        
# wait until connection is ready
sleep 1
for _ in {1..15}; do 
    if ! pgrep -f ssh &>/dev/null; then
        info "ssh exited, abort"
        exit
    fi
    # no curl test with socks here as dns server may not ready yet.
    if [ "$MODE" = route ]; then
        if ping -c 3 -O "$SSH_REMOTE"; then
            established=true && break
        fi
    else
        if ss -tunlp | grep -Fwq "$SOCKS5_PORT"; then
            established=true && break
        fi
    fi
    info "wait for connection"
    sleep 3
done

if [ -z "$established" ]; then
    info "ssh connection failed"
    tail "$SSH_LOGFILE"
    exit 1
fi
