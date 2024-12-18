#!/bin/bash
#
# s6-overlay breaks a job into pieces => complexity

info () {
    echo -e "==\\033[31m $(date '+%Y/%m/%d %H:%M:%S'): $* \\033[0m" >&2
}

if [ -z "$1" ]; then
    if [ -n "$PUID" ]; then
        info "**** apply uid $PUID ****"
        usermod www-data -u $PUID 2>/dev/null ||
        useradd www-data -u $PUID -U -M -s /sbin/nologin
    fi

    if [ -n "$PGID" ] && [ "$PGID" -ne "${PUID:-1000}" ]; then
        info "**** apply gid $PGID ****"
        groupmod www-data -g $PGID
    fi

    if [ ! -f /etc/nginx/nginx.conf ]; then
        info "**** apply default configs ****"
        rsync -av /etc/nginx.default/ /etc/nginx/
    fi

    info "**** apply default settings ****"
    sed -e 's/^user\ .*;$/user www-data;/' \
        -e '/^daemon/s/^/#/' \
        -e '/^master_process/s/^/#/' \
        -i /etc/nginx/nginx.conf

    mkdir -p /var/lib/nginx /var/log/nginx
    chown -R www-data /var/lib/nginx /var/log/nginx
    chmod -R 0750 /var/log/nginx
    
    # some directories included by nginx.conf
    mkdir -p /etc/nginx/conf.d
    mkdir -p /etc/nginx/sites-enabled
    mkdir -p /etc/nginx/streams-enabled

    info "**** start nginx process ****"
    $(which nginx) -g "daemon on; master_process on;"

    info "**** start nginx-ui process ****"
    mkdir -p /etc/nginx-ui
    exec $(which nginx-ui) -config /etc/nginx-ui/app.ini
    
    # don't tail log files here because of logrotate
else
    exec "$@"
fi
