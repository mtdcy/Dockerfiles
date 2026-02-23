#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    exec "$@"
else
    # apply PUID:PGID
    [ -z "$PUID" ] || usermod nvim -u "$PUID" 2>/dev/null || true
    [ -z "$PGID" ] || groupmod nvim -g "$PGID" 2>/dev/null || true

    exec sudo -u nvim "$@"
fi
