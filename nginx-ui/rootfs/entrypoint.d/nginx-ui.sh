#!/bin/bash
#
# Notes:
#   1. root permission is required

NGX_UI_LOGFILE="${NGX_UI_LOGFILE:-/var/log/nginx-ui.log}"
mkdir -p "$(dirname "$NGX_UI_LOGFILE")"
mkdir -p /etc/nginx-ui/

exec nginx-ui -config /etc/nginx-ui/app.ini > "$NGX_UI_LOGFILE" 2>&1
