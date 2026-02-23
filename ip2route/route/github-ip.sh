#!/bin/bash 

url=https://api.github.com/meta 
out=/tmp/github-$(basename $url).json

wget $url -O $out || exit 1

echo "# $url" > github-full.ip
grep -o -E "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\/[0-9]+" $out | sed 's%/32%%g' | uniq >> github-full.ip
