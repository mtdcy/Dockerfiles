#!/bin/bash

# options           =
                MODE="${MODE:basic}"
      TCP_CONGESTION="${TCP_CONGESTION:-bbr}"

info() {
    echo -e "🚀\\033[32m $* \\033[0m🚀"
}

if [ "$MODE" = basic ]; then
    info "skip sysctls in basic mode"
    exit 0
fi

cat <<EOF | sed 's/#.*$//g;/^\s*$/d' | xargs sysctl -w
# ip forward
net.ipv4.ip_forward=1

# TFO: tcp fast open
net.ipv4.tcp_fastopen=3

# tcp timeout
net.ipv4.tcp_keepalive_time=600 # 10 min
net.ipv4.tcp_keepalive_intvl=45 # 45 sec
net.ipv4.tcp_keepalive_probes=3
net.ipv4.tcp_fin_timeout=45

# tcp congestion control, needs kmod tcp_bbr
#  => https://lvv.me/posts/2021/03/20_linux_tcp_bbr/
#   => test with iperf3 and check Bitrate & Retr
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control="$TCP_CONGESTION"

# tcp/udp window size
net.core.rmem_default=1048576 # 1M
net.core.wmem_default=1048576
net.core.rmem_max=2097152 # 2M
net.core.wmem_max=2097152

# tcp window size [min default max]
net.ipv4.tcp_rmem="4096 1048576 2097152"
net.ipv4.tcp_wmem="4096 1048576 2097152"

# prevent SYN attack, enable SYNcookies
# see details in https://help.aliyun.com/knowledge_detail/41334.html
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_synack_retries=2
net.ipv4.tcp_max_tw_buckets=5000
net.ipv4.tcp_max_syn_backlog=4096

# https://feisky.gitbooks.io/sdn/content/linux/params.html
# conntrack: 4G
net.netfilter.nf_conntrack_buckets=65536
net.netfilter.nf_conntrack_max=262144
net.netfilter.nf_conntrack_tcp_timeout_established=300
net.netfilter.nf_conntrack_acct=1

# disable bridge nf to improve performance
net.bridge.bridge-nf-call-iptables=0
net.bridge.bridge-nf-call-ip6tables=0
net.bridge.bridge-nf-call-arptables=0
EOF

# ignore errors
exit 0
