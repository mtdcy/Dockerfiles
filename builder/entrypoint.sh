#!/bin/bash -e

export PUID="${PUID:-0}"
export PGID="${PGID:-0}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Please set PUID and PGID instead"
    exit 1
fi

cmd=( "${@:-bash}" )

# sudo: handle_sigchld_pty: waitpid: No child processes
reap_children() {
    while wait -n; do
        :
    done
}
trap 'reap_children' SIGCHLD # trap SIGCHLD => no exec permitted

getent passwd "$PUID" >/dev/null || usermod  buildbot -u "$PUID" || true
getent group  "$PGID" >/dev/null || groupmod buildbot -g "$PGID" || true

# enable binfmt support
if test -n "$WINEPREFIX" && which wine &>/dev/null; then
    if ! test -e /proc/sys/fs/binfmt_misc/wine; then
        sudo mount -t binfmt_misc none /proc/sys/fs/binfmt_misc
        sudo update-binfmts --import wine
        sudo update-binfmts --enable wine &>/dev/null
    fi

    # wine: '/wine' is not owned by you
    [ "$(stat -c %u "$WINEPREFIX")" -eq $PUID ] || chown -R $PUID "$WINEPREFIX"

    # programs may hang when wineserver is running due to pid conflicts.
    #sudo -u "#$PUID" -g "#$PGID" -E -H wineserver -p
fi

# su in alpine has no '--pty' option
#su buildbot --pty -c "$*"
# --pty: pseudo-terminal
# --login: will change the workdir and clear envs

sudo -u "#$PUID" -g "#$PGID" -E -H "${cmd[@]}"
# -E: preserve envs (no login shell)
# -H: set HOME
