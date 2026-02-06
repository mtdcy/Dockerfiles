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

if [ "$(id -u)" -ne 0 ]; then
    bash -c "${cmd[*]}"
else
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
