#!/bin/bash

# options           =
                MODE="${MODE:basic}"
      TCP_CONGESTION="${TCP_CONGESTION:-bbr}"

info() {
    echo -e "🚀\\033[32m $* \\033[0m🚀"
}

echocmd() {
    echo -e "--\\033[34m $* \\033[0m"
    "$@"
}

if [ "$MODE" = basic ]; then
    info "skip sysctls in basic mode"
    exit 0
fi

echocmd sysctl -w net.ipv4.ip_forward=1

# TFO: tcp fast open
echocmd sysctl -w net.ipv4.tcp_fastopen=3

# tcp timeout
echocmd sysctl -w net.ipv4.tcp_keepalive_time=600 # 10 min
echocmd sysctl -w net.ipv4.tcp_keepalive_intvl=45 # 45 sec
echocmd sysctl -w net.ipv4.tcp_keepalive_probes=3
echocmd sysctl -w net.ipv4.tcp_fin_timeout=45

# tcp congestion control, needs kmod tcp_bbr
#  => https://lvv.me/posts/2021/03/20_linux_tcp_bbr/
#   => test with iperf3 and check Bitrate & Retr
echocmd sysctl -w net.core.default_qdisc=fq
echocmd sysctl -w net.ipv4.tcp_congestion_control="$TCP_CONGESTION"

# tcp/udp window size
echocmd sysctl -w net.core.rmem_default=1048576 # 1M
echocmd sysctl -w net.core.wmem_default=1048576
echocmd sysctl -w net.core.rmem_max=2097152 # 2M
echocmd sysctl -w net.core.wmem_max=2097152

# tcp window size [min default max]
echocmd sysctl -w net.ipv4.tcp_rmem="4096 1048576 2097152"
echocmd sysctl -w net.ipv4.tcp_wmem="4096 1048576 2097152"

# prevent SYN attack, enable SYNcookies
# see details in https://help.aliyun.com/knowledge_detail/41334.html
echocmd sysctl -w net.ipv4.tcp_syncookies=1
echocmd sysctl -w net.ipv4.tcp_synack_retries=2
echocmd sysctl -w net.ipv4.tcp_max_tw_buckets=5000
echocmd sysctl -w net.ipv4.tcp_max_syn_backlog=4096

# ignore errors
exit 0
