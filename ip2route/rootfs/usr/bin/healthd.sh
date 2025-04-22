#!/bin/bash -e

while sleep 60; do
    if [ -n "$REMOTE_HOST" ]; then
        # socks5 check
        curl --fail -sI -x "socks5h://127.0.0.1:$SOCKS5_PORT" https://google.com

        dig @127.0.0.1 -p "$DNS2SOCKS_PORT" www.google.com
    fi

    dig www.google.com
done
