#!/bin/bash -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root and set PUID|PGID instead."
    exit 1
fi

export PUID="${PUID:-0}"
export PGID="${PGID:-0}"

if [ "$PUID" -gt 0 ]; then
    [ "$PUID" -eq "$(id -u buildbot)" ] || usermod  buildbot -u "$PUID" || true
    [ "$PGID" -eq "$(id -u buildbot)" ] || groupmod buildbot -g "$PGID" || true

    # shellcheck disable=SC2145
    su buildbot -c "$@"
else
    eval -- "$*"
fi
