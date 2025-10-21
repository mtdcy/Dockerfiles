#!/bin/bash -e
#
# s6-overlay breaks a job into pieces => complexity

info () {
    echo -e "🐳\\033[34m [$(date '+%Y/%m/%d %H:%M:%S')] $* \\033[0m" >&2
}

if [ -z "$1" ]; then
    if [ -n "$UMASK" ]; then
        info "**** apply umask $UMASK ****"
        umask "$UMASK"
    fi

    if [ -n "$PUID" ] && [ "$PUID" -ne "$(id -u www-data)" ]; then
        info "**** apply uid $PUID ****"
        usermod www-data -u "$PUID" 2>/dev/null ||
        useradd www-data -u "$PUID" -U -M -s /sbin/nologin
    fi

    if [ -n "$PGID" ] && [ "$PGID" -ne "$(id -g www-data)" ]; then
        info "**** apply gid $PGID ****"
        groupmod www-data -g "$PGID" || true
    fi

    if [ ! -f /etc/nginx/nginx.conf ]; then
        info "**** apply default configs ****"
        mkdir -p /etc/nginx
        cp -rfv /etc/nginx.default/* /etc/nginx/
        chown -R www-data /etc/nginx
    fi

    info "**** apply default settings ****"
    sed -e 's%^user\ .*;$%user www-data;%' \
        -e 's%^pid\ .*;$%pid /var/run/nginx.pid;%' \
        -e '/^daemon/s/^/#/' \
        -e '/^master_process/s/^/#/' \
        -i /etc/nginx/nginx.conf

    mkdir -p /var/lib/nginx /var/log/nginx /var/run/nginx
    chown -R www-data /var/lib/nginx /var/log/nginx
    chmod -R 0750 /var/log/nginx

    touch /var/log/nginx/access.log
    touch /var/log/nginx/error.log

    # some directories included by nginx.conf
    mkdir -p /etc/nginx/conf.d
    mkdir -p /etc/nginx/sites-available
    mkdir -p /etc/nginx/sites-enabled
    mkdir -p /etc/nginx/streams-available
    mkdir -p /etc/nginx/streams-enabled

    # always start plugins as root
    for x in /entrypoint.d/*; do
        info "**** start plugins $(basename "$x") ****"
        bash "$x"
        sleep 1
    done

    info "**** start crontab process ****"
    /usr/sbin/cron -P -f 2>&1 | tee -a /var/log/cron.log &

    if which cmdlets.sh && test -n "$NGX_VERSION"; then
        # try update nginx
        cmdlets.sh install nginx@$NGX_VERSION || true
    fi

    info "**** start nginx process ****"
    exec $(which nginx) -g "daemon off; master_process on;"

    # don't tail log files here because of logrotate
else
    exec "$@"
fi
