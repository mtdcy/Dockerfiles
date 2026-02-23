#!/bin/bash

url=${1:-https://www.gstatic.com/ipranges/goog.json}
out=/tmp/$$-google.json
ips=${2:-google-full.ip}

wget $url -O $out

echo "# $url" > $ips
grep -o -E "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\/[0-9]+" $out | sed 's%/32%%g' | uniq >> $ips

[ $# -eq 0 ] && $0 https://www.gstatic.com/ipranges/cloud.json google-cloud.ip
