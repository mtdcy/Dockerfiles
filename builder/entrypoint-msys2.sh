#!/bin/bash -e

[ -f /opt/.env ] && . /opt/.env || true

export PUID="${PUID:-0}"
export PGID="${PGID:-0}"

export WINEPREFIX="${WINEPREFIX:-/wine}"
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEPATH="${WINEPATH:-C:\\msys64\\usr\\bin}"

# wine+msys2 reports OSTYPE=cygwin
export OSTYPE=msys
export MSYSTEM="${MSYSTEM:-UCRT64}"

cmd=( "${@:-bash}" )

if [ "$(id -u)" -ne 0 ]; then
    # wine only test ownership on top directory
    # chown root:root "$WINEPREFIX"

    exec msys2 -c "${cmd[*]}"
else
    [ "$PUID" -eq "$(id -u buildbot)" ] || usermod  buildbot -u "$PUID" 2>/dev/null || true
    [ "$PGID" -eq "$(id -u buildbot)" ] || groupmod buildbot -g "$PGID" 2>/dev/null || true

    # wine only test ownership on top directory
    chown buildbot:buildbot "$WINEPREFIX"

    # ln: failed to create symbolic link '/etc/mtab': Permission denied
    chown buildbot:buildbot "/msys64/etc/mtab"

    exec sudo -E -u buildbot -H msys2 -c "${cmd[*]}"
fi
