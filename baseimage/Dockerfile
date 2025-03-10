# syntax=docker/dockerfile:1

# download or build using stage
FROM alpine:3 AS stage

WORKDIR /rootfs

ARG MIRROR
ARG S6_VERSION=3.1.6.2
RUN <<-EOS
    set -ex
    echo "**** prepare tools ****"

    if test -n "${MIRROR}"; then
        sed -e "s|https://dl-cdn.alpinelinux.org|${MIRROR}|g" -i /etc/apk/repositories || true
    fi
    apk add --no-cache wget xz

    echo "**** prepare s6 overlay for $(uname -m) ****"
    cd /tmp
    wget https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-noarch.tar.xz
    wget https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-$(uname -m).tar.xz
    wget https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-symlinks-noarch.tar.xz
    wget https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-symlinks-arch.tar.xz
    find /tmp -name "s6-overlay-*" -exec tar -C /rootfs -Jxpf {} \;
    du -a -h | tee /rootfs/installed-files
EOS

FROM ubuntu:latest

# labels
LABEL maintainer="mtdcy.chen@gmail.com"

ARG TZ=Asia/Shanghai
ARG LANG=en_US.UTF-8
ARG MIRROR
RUN <<-EOS
    set -ex
    echo "**** apply mirrors ****"

    if test -n "${MIRROR}"; then
        sed -e "s|https\?://archive.ubuntu.com|${MIRROR}|g" \
            -e "s|https\?://security.ubuntu.com|${MIRROR}|g" \
            -e "s|https\?://ports.ubuntu.com|${MIRROR}|g" \
            -i /etc/apt/sources.list \
            -i /etc/apt/sources.list.d/* || true
        sed -e "s|https\?://dl-cdn.alpinelinux.org|${MIRROR}|g" \
            -i /etc/apk/repositories || true
    fi

    echo "**** install essentials ****"

    if which apt-get; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y \
            bash locales tzdata \
            wget curl \
            tar xz-utils zstd lzip \
            procps \
            iputils-ping \
            bind9-dnsutils \
            sudo
        apt-get clean
        rm -rf /var/lib/apt/lists/* /var/tmp/* /var/log/*
    else
        apk update
        apk add --no-cache \
            bash shadow \
            musl-locales tzdata \
            wget curl \
            tar xz zstd lzip \
            procps \
            iputils \
            bind-tools \
            sudo
    fi

    echo "**** post setup ****"

    which locale-gen && locale-gen en_US.UTF-8 || true
    if [ -e /usr/share/zoneinfo/$TZ ]; then
        ln -svf /usr/share/zoneinfo/$TZ /etc/localtime
        echo "$TZ" > /etc/timezone
    else
        echo ">>>> wrong TZ:$TZ <<<<"; \
    fi
    userdel ubuntu || true
EOS

ENV TZ=${TZ}
ENV LANG=${LANG}
ENV LC_ALL=${LANG}

# s6: strange behavior
ENV S6_KEEP_ENV=1

COPY --from=stage /rootfs/ /

ENTRYPOINT ["/init"]
