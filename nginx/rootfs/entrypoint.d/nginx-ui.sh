#!/bin/bash
#
# Notes:
#   1. root permission is required

NGX_UI_LOGFILE="/var/log/nginx/ui.log"

mkdir -p "$(dirname "$NGX_UI_LOGFILE")"

test -f /etc/nginx/nginx-ui.ini || cp -fv /etc/nginx.default/nginx-ui.ini /etc/nginx/

exec nginx-ui -config /etc/nginx/nginx-ui.ini > "$NGX_UI_LOGFILE" 2>&1
