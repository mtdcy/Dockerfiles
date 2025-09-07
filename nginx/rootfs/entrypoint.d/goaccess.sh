#!/bin/bash

# options           =
        GOACCESS_URL="${GOACCESS_URL:-}"
       GOACCESS_PORT="${GOACCESS_PORT:-7890}"

test -f /etc/nginx/goaccess.conf || cp -fv /etc/nginx.default/goaccess.conf /etc/nginx/

# realtime
opts=( --real-time-html --keep-last=30 )

# conf
opts+=( -p /etc/nginx/goaccess.conf )

# output
opts+=( -o /var/www/html/report.html )

# ws-url
[ -z "$GOACCESS_URL" ] || opts+=( --ws-url="$GOACCESS_URL" )

# port
[ -z "$GOACCESS_PORT" ] || opts+=( --port="$GOACCESS_PORT" )

goaccess /var/log/nginx/access.log "${opts[@]}" 2>&1 | tee -a /var/log/goaccess.log & disown
