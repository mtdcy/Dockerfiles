#!/bin/bash -x

/usr/bin/ip2route.sh 00 dns "$REMOTE_ADDR" "tun${LOCAL_TUN:-0}"
