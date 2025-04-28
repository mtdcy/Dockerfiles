#!/bin/bash

sysctl -w net.ipv4.ip_forward=1

# window size
sysctl -w net.core.rmem_default=1048576
sysctl -w net.core.wmem_default=1048576
sysctl -w net.core.rmem_max=2097152
sysctl -w net.core.wmem_max=2097152

# prevent SYN attack, enable SYNcookies
# see details in https://help.aliyun.com/knowledge_detail/41334.html
sysctl -w net.ipv4.tcp_syncookies=1
sysctl -w net.ipv4.tcp_synack_retries=2
sysctl -w net.ipv4.tcp_max_tw_buckets=5000
sysctl -w net.ipv4.tcp_max_syn_backlog=4096

# ignore errors
exit 0
