#!/bin/bash -e

[ -f /opt/.env ] && . /opt/.env || true

export PUID="${PUID:-0}"
export PGID="${PGID:-0}"

cmd=( "${@:-bash}" )

if [ "$(id -u)" -ne 0 ]; then
    exec "${cmd[@]}"
else
    [ "$PUID" -eq "$(id -u buildbot)" ] || usermod  buildbot -u "$PUID" 2>/dev/null || true
    [ "$PGID" -eq "$(id -u buildbot)" ] || groupmod buildbot -g "$PGID" 2>/dev/null || true

    # su in alpine has no '--pty' option
    #su buildbot --pty -c "$*"
    # --pty: pseudo-terminal
    # --login: will change the workdir and clear envs
    
    exec sudo -E -u buildbot -H "${cmd[@]}"
    # -E: preserve envs (no login shell)
    # -H: set HOME
fi
