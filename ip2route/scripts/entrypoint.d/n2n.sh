#!/bin/bash -e
#
# options           =
                MODE="${MODE:-serve}" # route,serve
            
         REMOTE_HOST="${REMOTE_HOST:-n2n://test@127.0.0.1:7654}" # -l, route mode

        LOCAL_DEVICE="${LOCAL_DEVICE:-n2n0}" # -d
          LOCAL_ADDR="${LOCAL_ADDR:-10.0.0.1/24}"
         REMOTE_ADDR="${REMOTE_ADDR:-}"

             N2N_KEY="${N2N_KEY:-}"
            N2N_FILE="${N2N_FILE:-/config/n2n.comm}" # -c, serve mode
         N2N_LOGFILE="${N2N_LOGFILE:-/var/log/n2n.log}"
            N2N_OPTS="${N2N_OPTS:-}" # route mode

info() {
    echo -e "🚀\\033[32m $* \\033[0m🚀"
}

echocmd() {
    echo -e "--\\033[34m $* \\033[0m"
    "$@"
}

args=(
    -v # verbose
)

if [ "$1" = clean ]; then
    info "clean n2n tunnel $LOCAL_DEVICE"

    pkill -f -INT supernode || true
    pkill -f -INT edge || true

    echocmd /entrypoint.d/iptables.sh flush "$LOCAL_DEVICE"

    exit
fi

# generate fixed mac addr
read -r -a seq <<< "$(od -A n -t x1 <<< "$(hostname)$LOCAL_ADDR")"
mac="${seq[*]:0:5}"
mac="${mac// /:}"

if [ "$MODE" = serve ]; then
    info "init n2n network"

    n2n=( /usr/sbin/supernode "${args[@]}" )
    # disable mac spoof
    n2n+=( -M )
    # mac
    #n2n+=( -m "AA:$mac" )
    # community file
    [ -f "$N2N_FILE" ] && n2n+=( -c "$N2N_FILE" ) || true
    # user opts
    [ -z "${N2N_OPTS[*]}" ] || n2n+=( "${N2N_OPTS[@]}" )

    info "${n2n[*]}"
    "${n2n[@]}" -f 2>&1 | tee -a "$N2N_LOGFILE" & disown

    exit 0
fi

info "init n2n network @$LOCAL_DEVICE - $LOCAL_ADDR - $REMOTE_ADDR"

IFS='@:' read -r user host port <<< "${REMOTE_HOST#*//}"
N2N_COMMUNITY="$user"

# simplify configurations
[ -n "$N2N_KEY" ] || N2N_KEY="$N2N_COMMUNITY"

# edge mac addr may changes, so flush arp first
echocmd ip neighbor flush all

echocmd /entrypoint.d/iptables.sh flush "$LOCAL_DEVICE" || true

# check net mask
[[ "$LOCAL_ADDR" =~ / ]] || LOCAL_ADDR="$LOCAL_ADDR/24"

# client mode
n2n=( /usr/sbin/edge "${args[@]}" )
# multicast
n2n+=( -E )
# head encrypt
n2n+=( -H )
# MTU & PMTU
n2n+=( -M 1248 -D )
# remote
n2n+=( -l "$host:$port" )
# tap 
n2n+=( -d "$LOCAL_DEVICE" )
# ip addr
n2n+=( -a "static:$LOCAL_ADDR" )
# mac
n2n+=( -m "EE:$mac" )
# forwarding
n2n+=( -r )
# user opts
[ -z "${N2N_OPTS[*]}" ] || n2n+=( "${N2N_OPTS[@]}" )

# use env instead of args
export N2N_COMMUNITY N2N_KEY
#n2n+=( -k "$N2N_KEY" )
#n2n+=( -c "$N2N_COMMUNITY" )

info "${n2n[*]}"
"${n2n[@]}" -f 2>&1 | tee -a "$N2N_LOGFILE" & disown

sleep 1

# bugfix: mac addr
echocmd ip link set dev "$LOCAL_DEVICE" addr "EE:$mac"
echocmd /entrypoint.d/iptables.sh "$LOCAL_DEVICE" "$LOCAL_ADDR" "$REMOTE_ADDR"

if [ -n "$REMOTE_ADDR" ]; then
    for _ in {1..9}; do
        if echocmd ping -c 1 -q "$REMOTE_ADDR"; then
            connected=true && break
        fi
        info "wait for n2n connection"
        sleep 3
    done
    if [ -z "$connected" ]; then
        info "n2n connection failed"
        exit 1
    fi
fi
