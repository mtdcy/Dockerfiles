#!/bin/bash -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root and set PUID|PGID instead."
    exit 1
fi

export PUID="${PUID:-0}"
export PGID="${PGID:-0}"

export WINEPREFIX="${WINEPREFIX:-/wine}"
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEPATH="${WINEPATH:-C:\\msys64\\usr\\bin}"

# wine+msys2 reports OSTYPE=cygwin
export OSTYPE=msys
export MSYSTEM="${MSYSTEM:-UCRT64}"

if [ "$PUID" -gt 0 ]; then
    [ "$PUID" -eq "$(id -u buildbot)" ] || usermod  buildbot -u "$PUID" || true
    [ "$PGID" -eq "$(id -u buildbot)" ] || groupmod buildbot -g "$PGID" || true

    # wine only test ownership on top directory
    chown buildbot:buildbot "$WINEPREFIX"

    # ln: failed to create symbolic link '/etc/mtab': Permission denied
    chown buildbot:buildbot "/msys64/etc/mtab"

    [ -n "$1" ] && su buildbot -c "msys2 -l -c '$@'" || su buildbot -c msys2
else
    # wine only test ownership on top directory
    chown root:root "$WINEPREFIX"

    [ -n "$1" ] && msys2 -l -c "$@" || msys2
fi
