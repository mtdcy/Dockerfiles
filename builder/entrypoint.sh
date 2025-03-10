#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root and set PUID|PGID instead."
    exit 1
fi

# start a login shell
[ -n "$*" ] || exec bash -li

export PUID="${PUID:-0}"
export PGID="${PGID:-0}"

if [ "$PUID" -gt 0 ]; then
    id -u buildbot &>/dev/null || useradd -U -m -s /bin/bash buildbot

    [ "$PUID" -eq 0 ] || usermod  buildbot -u "$PUID" || true
    [ "$PGID" -eq 0 ] || groupmod buildbot -g "$PGID" || true
    # shellcheck disable=SC2145
    su buildbot -c "$@"
else
    eval -- "$*"
fi
