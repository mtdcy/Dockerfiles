#!/bin/sh
#
# s6-overlay breaks a job into pieces => complexity

set -e

if [ -z "$1" ]; then
    # prepare omnicache dirs
    u=$(awk '/^user/ { print substr($2, 1, length($2)-1) }' < /app/nginx/nginx.conf)
    chmod -R 0755 /app /var/lib/nginx
    chmod -R 0750 /var/log/nginx
    chown -R ${u:-www-data} /app /var/lib/nginx /var/log/nginx

    # foreground => log to stdout
    start-stop-daemon --start    \
        --make-pidfile           \
        --pidfile /run/nginx.pid \
        --exec "$(which nginx)" -- -g "daemon off; master_process on;"
    
    # don't tail log files here because of logrotate
else
    exec "$@"
fi
