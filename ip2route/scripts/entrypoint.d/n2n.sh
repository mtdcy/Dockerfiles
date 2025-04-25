#!/bin/bash -e
#
# options           =
                MODE="${MODE:-serve}" # route,serve
            
         REMOTE_HOST="${REMOTE_HOST:-n2n://test@127.0.0.1:7654}" # -l, route mode
            N2N_PORT="${N2N_PORT:-${REMOTE_HOST##*:}}" # -p, serve mode

          N2N_DEVICE="${N2N_DEVICE:-n2n0}" # -d
            N2N_ADDR="${N2N_ADDR:-10.0.0.1/24}"
          N2N_REMOTE="${N2N_REMOTE:-}"

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
    info "clean n2n tunnel $N2N_DEVICE"

    echocmd /entrypoint.d/iptables.sh flush "$N2N_DEVICE"

    exit
fi

IFS='@:' read -r user host port <<< "${REMOTE_HOST#*//}"
N2N_COMMUNITY="$user"

# simplify configurations
[ -n "$N2N_KEY" ] || N2N_KEY="$user"
if [ -z "$N2N_KEY" ]; then
    N2N_KEY="$(openssl rand -hex 7)" # <= 19 chars
    info "*** generated N2N_KEY: $N2N_KEY ***"
fi

if [ "$MODE" = serve ]; then
    info "init n2n network @127.0.0.1:$N2N_PORT"

    # init community file
    [ -f "$N2N_FILE" ] || echo "$N2N_COMMUNITY" > "$N2N_FILE"

    # append community
    grep -q "^$N2N_COMMUNITY" "$N2N_FILE" || echo "$N2N_COMMUNITY" >> "$N2N_FILE"

    n2n=( /usr/sbin/supernode "${args[@]}" )
    # disable mac spoof
    n2n+=( -M )
    # listen port
    n2n+=( -p "$N2N_PORT" )
    # community file
    [ -f "$N2N_FILE" ] && n2n+=( -c "$N2N_FILE" ) || true

    info "${n2n[*]}"
    "${n2n[@]}" -f 2>&1 | tee -a "$N2N_LOGFILE" & disown

    sleep 1
    [ -n "$REMOTE_HOST" ] || {
        info "*** no remote host, skip client setup ***"
        exit 0
    }
fi

info "init n2n network @$N2N_DEVICE - $N2N_ADDR"

echocmd /entrypoint.d/iptables.sh flush "$N2N_DEVICE" || true

# client mode
n2n=( /usr/sbin/edge "${args[@]}" )
# head encrypt
n2n+=( -H )
# MTU & PMTU
n2n+=( -M 1248 -D )
# remote
n2n+=( -l "$host:$port" )
# tap 
n2n+=( -d "$N2N_DEVICE" )
# ip addr
n2n+=( -a "static:$N2N_ADDR" )
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

echocmd /entrypoint.d/iptables.sh "$N2N_DEVICE" "$N2N_ADDR" "$N2N_REMOTE"

if [ -n "$N2N_REMOTE" ]; then
    for _ in {1..9}; do
        if echocmd ping -c 3 -O "$N2N_REMOTE"; then
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
