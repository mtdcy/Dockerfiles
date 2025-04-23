# syntax=docker/dockerfile:1

FROM baseimage:latest

ARG VERSION=1.0.0

# lables
LABEL maintainer="mtdcy.chen@gmail.com" version="$VERSION"

RUN <<-EOS
    set -ex
    echo "**** install essentials ****"

    apt-get update
    apt-get install -y -q             \
        kmod iptables ipset           \
        iproute2 traceroute           \
        openssh-client openssh-server \
        dnsmasq
EOS

COPY scripts/ /

ARG TARGETPLATFORM
COPY dns2socks/$TARGETPLATFORM/ /

VOLUME /config

WORKDIR /config

# dns
EXPOSE 53/tcp 53/udp 
# dhcp
EXPOSE 67/udp
# socks5
EXPOSE 1070

ENTRYPOINT ["/entrypoint.sh"]
