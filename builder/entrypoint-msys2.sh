#!/bin/bash -e

export WINE=$({ which wine64 || which wine; } 2>/dev/null)
export WINEDEBUG="${WINEDEBUG:--all}"
export MSYSTEM="${MSYSTEM:-UCRT64}"

export PUID="${PUID:-0}"
export PGID="${PGID:-0}"

if [ "$*" = "bash" ]; then
    exec bash -li
elif [ -n "$*" ]; then
    "$WINE" bash.exe -l -c "$@"
else
    "$WINE" bash.exe -l
fi
