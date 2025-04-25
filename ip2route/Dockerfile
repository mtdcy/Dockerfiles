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
    apt-get install -y -q             \
        kmod iptables ipset           \
        iproute2 traceroute           \
        openssh-client openssh-server \
        dnsmasq moreutils ipcalc-ng
EOS

COPY scripts/ /

ARG TARGETPLATFORM
COPY dns2socks/$TARGETPLATFORM/ /

COPY --from=builder /rootfs/ /

VOLUME /config

WORKDIR /config

# dns
EXPOSE 53/tcp 53/udp 
# dhcp
EXPOSE 67/udp
# socks5
EXPOSE 1070

ENTRYPOINT ["/entrypoint.sh"]
