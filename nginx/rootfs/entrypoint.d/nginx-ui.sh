#!/bin/bash
#
# Notes:
#   1. root permission is required

NGX_UI_LOGFILE="/var/log/nginx/ui.log"

mkdir -p "$(dirname "$NGX_UI_LOGFILE")"

# nginx-ui配置好像不太稳定，更新之后原配置会导致一定问题
#  => 如遇到问题，请删除原有配置文件，重新安装
test -f /etc/nginx/ui/app.ini || {
    mkdir -pv /etc/nginx/ui
    cp -fv /etc/nginx.default/ui/app.ini /etc/nginx/ui/
}

nginx-ui -config /etc/nginx/ui/app.ini 2>&1 | tee -a "$NGX_UI_LOGFILE" & disown
