#!/bin/bash
#
# Notes:
#   1. root permission is required

NGX_UI_LOGFILE="/var/log/nginx/ui.log"

mkdir -p "$(dirname "$NGX_UI_LOGFILE")"

# nginx-ui配置好像不太稳定，更新之后原配置会导致一定问题
#  => 如遇到问题，请删除原有配置文件，重新安装
test -f /etc/nginx/ui.ini || touch /etc/nginx/ui.ini

exec nginx-ui -config /etc/nginx/ui.ini > "$NGX_UI_LOGFILE" 2>&1
