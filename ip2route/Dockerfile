# syntax=docker/dockerfile:1

FROM baseimage:latest AS builder

WORKDIR /tmp

ARG N2N_VERSION=3.1.1
RUN <<-EOS
    set -ex
    apt-get update 
    apt-get install -y -q build-essential autoconf automake pkg-config git libcap-dev

    git clone --depth 1 https://github.com/ntop/n2n.git -b $N2N_VERSION

    cd n2n
    ./autogen.sh
    ./configure --enable-cap
    make 
    DESTDIR=/rootfs make install
    
    du -a -h /rootfs | tee /rootfs/n2n-files
EOS

FROM baseimage:latest

ARG VERSION=1.0.0

# lables
LABEL maintainer="mtdcy.chen@gmail.com" version="$VERSION"

RUN <<-EOS
    set -ex
    echo "**** install essentials ****"

    apt-get update
    apt-get install -y -q               \
        kmod iptables ipset             \
        iproute2 traceroute             \
        openssh-client openssh-server   \
        dnsmasq moreutils ipcalc-ng     \
        iperf3 conntrack netcat-openbsd \
        dnsutils conntrack
EOS

COPY --from=builder /rootfs/ /

ARG TARGETPLATFORM
# https://github.com/ginuerzh/gost
ARG GOST_VERSION=2.12.0
ARG DNS2SOCKS_VERSION=0.2.0
SHELL ["/bin/bash", "-c"]
RUN <<-EOS
    set -ex
    
    echo "**** install gost ****"
    curl -sL https://github.com/ginuerzh/gost/releases/download/v$GOST_VERSION/gost_${GOST_VERSION}_${TARGETPLATFORM//\//_}.tar.gz | tar -C /usr/bin/ -xz gost
    
    echo "**** install dns2socks ****"
    DNS2SOCKS="https://github.com/tun2proxy/dns2socks/releases/download/v$DNS2SOCKS_VERSION/"
    case "$TARGETPLATFORM" in 
        linux/amd64)    DNS2SOCKS+="dns2socks-x86_64-unknown-linux-gnu.zip"     ;;
        linux/arm64)    DNS2SOCKS+="dns2socks-aarch64-unknown-linux-gnu.zip"    ;;
    esac

    wget "$DNS2SOCKS"
    DNS2SOCKS="$(basename "$DNS2SOCKS")"
    unzip "$DNS2SOCKS" dns2socks -d /usr/bin/
    rm -f "$DNS2SOCKS"
EOS

RUN ldconfig

COPY scripts/ /

ENV PATH=/entrypoint.d:$PATH

VOLUME /config

WORKDIR /config

# dns
EXPOSE 53/tcp 53/udp 
# dhcp
EXPOSE 67/udp
# socks5
EXPOSE 1070

ENTRYPOINT ["/entrypoint.sh"]
