#!/bin/bash -e

export PUID="${PUID:-0}"
export PGID="${PGID:-0}"

cmd=( "${@:-bash}" )

if [ "$(id -u)" -ne 0 ]; then
    exec "${cmd[@]}"
else
    getent passwd "$PUID" || usermod  buildbot -u "$PUID" || true
    getent group  "$PGID" || groupmod buildbot -g "$PGID" || true

    # su in alpine has no '--pty' option
    #su buildbot --pty -c "$*"
    # --pty: pseudo-terminal
    # --login: will change the workdir and clear envs

    exec sudo -u "#$PUID" -g "#$PGID" -E -H "${cmd[@]}"
    # -E: preserve envs (no login shell)
    # -H: set HOME
fi
