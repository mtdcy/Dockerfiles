#!/bin/bash
#
# PHP-FPM 启动脚本 (Docker 环境)
# 使用方法：/entrypoint.d/php-fpm.sh

set -e

# 日志文件
PHP_LOGFILE="/var/log/php-fpm.log"
PHP_ERROR_LOGFILE="/var/log/php-fpm-error.log"

# 创建日志目录
mkdir -p "$(dirname "$PHP_LOGFILE")"
mkdir -p "$(dirname "$PHP_ERROR_LOGFILE")"

# 检查 PHP-FPM 是否已安装
if ! command -v php-fpm &> /dev/null; then
    echo "[ERROR] php-fpm not found, please install first" | tee -a "$PHP_ERROR_LOGFILE"
    exit 1
fi

# PHP-FPM 配置文件
PHP_CONF="/etc/nginx/php-fpm.conf"
PHP_POOL_CONF="/etc/nginx/php-fpm.d/www.conf"

# 创建必要的目录
mkdir -p /run/php
mkdir -p /var/log/php-fpm
mkdir -p /var/lib/php/session
mkdir -p /var/lib/php/wsdlcache

# 设置权限
chmod 1733 /var/lib/php/session
chmod 1733 /var/lib/php/wsdlcache

# 检查是否有正在运行的 PHP-FPM 进程
if pgrep -x "php-fpm" > /dev/null; then
    echo "[INFO] PHP-FPM already running, reloading..." | tee -a "$PHP_LOGFILE"
    kill -USR2 $(cat /run/php-fpm.pid 2>/dev/null || pgrep -x "php-fpm" | head -1)
    sleep 2
fi

# 启动 PHP-FPM
echo "[INFO] Starting PHP-FPM..." | tee -a "$PHP_LOGFILE"

# 使用 Unix socket 模式
PHP_SOCKET="/run/php/php-fpm.sock"
echo "[INFO] Using Unix socket: $PHP_SOCKET" | tee -a "$PHP_LOGFILE"

# 确保 socket 目录存在
mkdir -p "$(dirname "$PHP_SOCKET")"

# 启动 PHP-FPM 主进程
if [ -f "$PHP_CONF" ]; then
    php-fpm --fpm-config "$PHP_CONF" --daemonize 2>&1
else
    echo "[WARN] PHP-FPM config not found, using default" | tee -a "$PHP_LOGFILE"
    php-fpm --daemonize 2>&1
fi

# 等待 PHP-FPM 启动
sleep 2

# 检查是否启动成功
if pgrep -x "php-fpm" > /dev/null; then
    echo "[OK] PHP-FPM started successfully" | tee -a "$PHP_LOGFILE"
    echo "[INFO] PID: $(cat /run/php-fpm.pid 2>/dev/null || pgrep -x "php-fpm" | head -1)" | tee -a "$PHP_LOGFILE"
else
    echo "[ERROR] PHP-FPM failed to start" | tee -a "$PHP_ERROR_LOGFILE"
    exit 1
fi

# 后台运行监控
(
    while true; do
        if ! pgrep -x "php-fpm" > /dev/null; then
            echo "[ERROR] PHP-FPM crashed, restarting..." | tee -a "$PHP_LOGFILE"
            php-fpm --daemonize 2>&1 | tee -a "$PHP_LOGFILE" &
        fi
        sleep 5
    done
) & disown

echo "[INFO] PHP-FPM monitor started" | tee -a "$PHP_LOGFILE"
