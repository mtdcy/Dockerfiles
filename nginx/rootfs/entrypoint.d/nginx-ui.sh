#!/bin/bash
#
# Notes:
#   1. root permission is required

NGX_UI_LOGFILE="/var/log/nginx/ui.log"

mkdir -p "$(dirname "$NGX_UI_LOGFILE")"

exec nginx-ui -config /etc/nginx/nginx-ui.ini > "$NGX_UI_LOGFILE" 2>&1
