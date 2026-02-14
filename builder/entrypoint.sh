#!/bin/bash -e

export PUID="${PUID:-0}"
export PGID="${PGID:-0}"

cmd=( "${@:-bash}" )

# sudo: handle_sigchld_pty: waitpid: No child processes
reap_children() {
    while wait -n; do
        :
    done
}
trap 'reap_children' SIGCHLD # trap SIGCHLD => no exec permitted

: "${WINEPREFIX:=}"

# enable binfmt support
if test -n "$WINEPREFIX" && ! test -e /proc/sys/fs/binfmt_misc/wine; then
    sudo mount -t binfmt_misc none /proc/sys/fs/binfmt_misc
    sudo update-binfmts --import wine
    sudo update-binfmts --enable wine
fi

if [ "$(id -u)" -ne 0 ]; then
    # wine: '/wine' is not owned by you
    [ "$(stat -c %u "$WINEPREFIX")" -eq $(id -u) ] || chown -R $(id -u) "$WINEPREFIX"

    bash -c "${cmd[*]}"
else
    # wine: '/wine' is not owned by you
    [ "$(stat -c %u "$WINEPREFIX")" -eq $PUID ] || chown -R $PUID "$WINEPREFIX"

    getent passwd "$PUID" >/dev/null || usermod  buildbot -u "$PUID" || true
    getent group  "$PGID" >/dev/null || groupmod buildbot -g "$PGID" || true

    # su in alpine has no '--pty' option
    #su buildbot --pty -c "$*"
    # --pty: pseudo-terminal
    # --login: will change the workdir and clear envs

    sudo -u "#$PUID" -g "#$PGID" -E -H -s /bin/bash -c "${cmd[*]}"
    # -E: preserve envs (no login shell)
    # -H: set HOME
fi
