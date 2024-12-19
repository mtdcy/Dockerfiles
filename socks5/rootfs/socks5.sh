#!/bin/bash

function usage {
    cat << EOF
socks5.sh <action [argument]> ...
    connect [user@]server[:port]    - connect remote server
    bind <ip:port>                  - bind local address
    ident <user>                    - specify identify file by user name
    verbose                         - run ssh in verbose mode
    help                            - show this help message.

Examples:
    socks5.sh connect user@example.com bind '*:1080' verbose > /dev/null 2>&1 &
EOF
}

# common options
sshc="ssh -CN -q"

# prevents reading from stdin
sshc+=" -n"

SSH_HOST="${SSH_HOST:-}"
SSH_BIND="${SSH_BIND:-*:1070}"
SSH_VERBOSE="${SSH_VERBOSE:-0}"

SSH_IDENT="${SSH_IDENT:-$HOME/.ssh/id_rsa}"
SSH_CONFIG="${SSH_CONFIG:-$HOME/.ssh/config}"

# optimized ssh parameters [high prio => override SSH_CONFIG]
IFS=' ' read -r -a SSH_OPTS <<< "$SSH_OPTS"
SSH_OPTS+=(
    TCPKeepAlive=yes                # spoofable
    ServerAliveInterval=15          # < 30s, send a null packet to server
    ServerAliveCountMax=3           # disconnect after max * interval
    ConnectTimeout=59               # wait before connectting timeout
    ConnectionAttempts=3            # attempts before stop connectting
    StrictHostKeyChecking=no        # no strict host key check
    ExitOnForwardFailure=yes        # exit if the connection cann't setup
)

while [ $# -gt 0 ]; do
    opt=$1; shift
    case $opt in
        connect)    SSH_HOST="$1"   ; shift ;;
        bind)       SSH_BIND="$1"   ; shift ;;
        ident)      SSH_IDENT="$1"  ; shift ;;
        config)     SSH_CONFIG="$1" ; shift ;;
        verbose)    SSH_VERBOSE=1           ;;
        help|*)     usage && exit 0         ;;
    esac
done

# sanity check
[ -z "$SSH_HOST" ] && echo "no ssh host specified, exit." && exit 1

IFS='@:' read -r user host port <<< "$SSH_HOST"

sshc+=" $user@$host -p $port"

if [ -n "$SSH_BIND" ]; then
    if [[ "$SSH_BIND" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]+$ ]]; then
        IFS=':' read -r addr port <<< "$SSH_BIND"
        sshc+=" -b $addr -D $addr:$port"
    else
        sshc+=" -B $SSH_BIND"
    fi
else
    sshc+=" -b 0.0.0.0:1070"
fi

if [ -n "$SSH_CONFIG" ]; then
    if [ ! -f "$SSH_CONFIG" ]; then
        echo "no $SSH_CONFIG, initial with system default."
        cp /etc/ssh/ssh_config "$SSH_CONFIG" || true
    fi

    sshc+=" -F $SSH_CONFIG"
else
    sshc+=" -F none"
fi

[ -n "$SSH_IDENT" ] && sshc+=" -i $SSH_IDENT"

for x in "${SSH_OPTS[@]}"; do
    [ -n "$x" ] && sshc+=" -o $x"
done

[ "$SSH_VERBOSE" -ne 0 ] && sshc+=" -v"

# starting socks5 tunnel
echo "[socks5] ${sshc}"

$sshc exit 3>&1 2>&1 |
while read -r line; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $line"
done

echo "[socks5] ssh tunnel closed unexpected ..."
