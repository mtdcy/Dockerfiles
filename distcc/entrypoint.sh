#!/bin/bash

if test -n "$@"; then
    exec "$@"
else
    distccd --daemon --no-detach \
        --verbose                \
        --user distcc            \
        --port 3632              \
        --stats                  \
        --stats-port 3633        \
        --listen 0.0.0.0         \
        $DISTCC_OPTS
fi
