#!/bin/bash -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root and set PUID|PGID instead."
    exit 1
fi

# enter container root
[ "$*" = "root" ] && exec bash -li

export WINEDEBUG="${WINEDEBUG:--all}"
export MSYSTEM="${MSYSTEM:-UCRT64}"
export WINEPREFIX="${WINEPREFIX}"

# bind workdir to MSYS2
#  'mount --bind' needs '--cap-add=SYS_ADMIN'
WORKDIR="$(pwd -P)"
#mkdir -pv "/msys64$(dirname "$WORKDIR")"
#ln -sf "$WORKDIR" "/msys64$WORKDIR"
mkdir -p "/msys64$WORKDIR"
mount --bind "$WORKDIR" "/msys64$WORKDIR"

export PUID="${PUID:-0}"
export PGID="${PGID:-0}"

id -u buildbot &>/dev/null || useradd -U -m -s /bin/bash buildbot

[ "$PUID" -eq 0 ] || usermod  buildbot -u "$PUID" || true
[ "$PGID" -eq 0 ] || groupmod buildbot -g "$PGID" || true

if [ "$PUID" -ne 0 ] || [ "$PGID" -ne 0 ]; then
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
fi

if [ -n "$*" ]; then
    # shellcheck disable=SC2145
    su buildbot -c "wine bash.exe -li -c '$@'"
else
    su buildbot -c "wine bash.exe -li"
fi
