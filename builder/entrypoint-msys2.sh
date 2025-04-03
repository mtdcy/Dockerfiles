#!/bin/bash -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root and set PUID|PGID instead."
    exit 1
fi

export WINEDEBUG="${WINEDEBUG:--all}"
export WINEPREFIX="${WINEPREFIX:-/wine}"

export OSTYPE=msys
export MSYSTEM="${MSYSTEM:-UCRT64}"

# start a login shell
[ -n "$*" ] || exec bash -li

# bind workdir to MSYS2
#  'mount --bind' needs '--cap-add=SYS_ADMIN'
WORKDIR="$(pwd -P)"
mkdir -p "/msys64$WORKDIR"
#ln -sf "$WORKDIR" "/msys64$WORKDIR"
mount --bind "$WORKDIR" "/msys64$WORKDIR"

export PUID="${PUID:-0}"
export PGID="${PGID:-0}"

if [ "$PUID" -gt 0 ]; then
    id -u buildbot &>/dev/null || useradd -U -m -s /bin/bash buildbot

    [ "$PUID" -eq 0 ] || usermod  buildbot -u "$PUID" || true
    [ "$PGID" -eq 0 ] || groupmod buildbot -g "$PGID" || true

    export WINEPREFIX=${WINEPREFIX:-~buildbot/.wine}

    if [ ! -d "$WINEPREFIX" ]; then
        su buildbot -c "wine winecfg /v ${WINDOWS:-win10}"
        ln -sfv /msys64 "$WINEPREFIX/dosdevices/d:"
        chown -R buildbot:buildbot /msys64
    fi

    # ln: failed to create symbolic link '/etc/mtab': Permission denied
    chown buildbot:buildbot "/msys64/etc/mtab"

    # wine only test ownership on top directory
    chown buildbot:buildbot "$WINEPREFIX"

    su buildbot -c "xvfb-run -a wine bash.exe -li -c '$@'"
else
    xvfb-run -a wine bash.exe -li -c "$@"
fi
