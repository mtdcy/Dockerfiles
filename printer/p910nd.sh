#!/bin/bash

export LC_ALL=C

#exec > >(logger -t $(basename $0))
#exec 2> >(logger -t $(basename $0) -p user.error)
#echo "=="

info() {
    echo "$@" > /dev/stderr
}

which p910nd > /dev/null || info "p910nd: not present ..."

INDEX=0
LPDEV=/dev/usb/lp$INDEX

while true; do
    [ -e $LPDEV ] && {
        info "p910nd: $LPDEV ..."
        p910nd -f $LPDEV -i 0.0.0.0 -b -d $INDEX || info "p910nd: exited ..."
    } || info "p910nd: wait for $LPDEV ..."
    sleep 60
done

echo "=="
