#!/bin/bash

[ "$PUID" -eq 0 ] || usermod  buildbot -u "$PUID" || true
[ "$PGID" -eq 0 ] || groupmod buildbot -g "$PGID" || true

if [ "$PUID" -ne 0 ] || [ "$PGID" -ne 0 ]; then
    # shellcheck disable=SC2145
    su buildbot -c "'$@'"
else
    "$@"
fi
