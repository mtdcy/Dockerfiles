# syntax=docker/dockerfile:1

FROM ubuntu:latest

# labels
LABEL maintainer="mtdcy.chen@gmail.com"

ARG TZ=Asia/Shanghai
ARG LANG=en_US.UTF-8
ARG MIRROR

ENV TZ=${TZ}
ENV LANG=${LANG}
ENV LC_ALL=${LANG}

ENV DEBIAN_FRONTEND=noninteractive
RUN <<-EOS
    set -ex
    echo "**** apply mirrors ****"

    if test -n "${MIRROR}"; then
        # Fix 'No system certificates available.' by using http
        sources=$(echo "$MIRROR" | sed -e 's/^https/http/' -e 's/:[0-9]\+$//')

        sed -e "s|https\?://archive.ubuntu.com|$sources|g"      \
            -e "s|https\?://security.ubuntu.com|$sources|g"     \
            -e "s|https\?://ports.ubuntu.com|$sources|g"        \
            -i /etc/apt/sources.list                            \
            -i /etc/apt/sources.list.d/ubuntu.sources || true
        sed -e "s|https\?://dl-cdn.alpinelinux.org|$sources|g"  \
            -i /etc/apk/repositories || true
    fi

    echo "**** install essentials ****"

    if which apt-get; then
        apt-get update

        # Fix: error processing package libc-bin
        apt-get --reinstall install -y libc-bin || true

        apt-get install -y               \
        ca-certificates                  \
            bash locales tzdata          \
            wget curl                    \
            tar xz-utils zstd lzip unzip \
            procps                       \
            iputils-ping                 \
            bind9-dnsutils               \
            sudo

        dpkg-reconfigure tzdata

        apt-get clean
        rm -rf /var/lib/apt/lists/* /var/tmp/* /var/log/*
    else
        apk update
        apk add --no-cache         \
            ca-certificates        \
            bash shadow            \
            musl-locales tzdata    \
            wget curl              \
            tar xz zstd lzip unzip \
            procps                 \
            iputils                \
            bind-tools             \
            sudo
    fi
        
    # Fix: Certificate verification failed: The certificate is NOT trusted.
    update-ca-certificates || true
   
    # set the right MIRROR
    if test -n "${MIRROR}"; then
        sed -e "s|$sources|$MIRROR|g" \
            -e "s|$sources|$MIRROR|g" \
            -e "s|$sources|$MIRROR|g" \
            -i /etc/apt/sources.list  \
            -i /etc/apt/sources.list.d/ubuntu.sources || true
        sed -e "s|$sources|$MIRROR|g" \
            -i /etc/apk/repositories || true
    fi

    echo "**** post setup ****"

    which locale-gen && locale-gen en_US.UTF-8 || true
    if [ -e /usr/share/zoneinfo/$TZ ]; then
        ln -svf /usr/share/zoneinfo/$TZ /etc/localtime
        echo "$TZ" > /etc/timezone
    else
        echo ">>>> wrong TZ:$TZ <<<<"
    fi

    userdel ubuntu || true
EOS
