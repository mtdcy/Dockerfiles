# syntax=docker/dockerfile:1
ARG BASEIMAGE

FROM ${BASEIMAGE:-ubuntu:latest}

# labels
LABEL maintainer="mtdcy.chen@gmail.com"

# ENV & ARG variables
ARG TZ=Asia/Shanghai
ENV TZ=${TZ}

#1
ARG MIRROR
RUN echo "**** apply mirrors ****" && \
    test -n "${MIRROR}" && { \
        sed -e "s|archive.ubuntu.com|${MIRROR}|g" \
            -e "s|security.ubuntu.com|${MIRROR}|g" \
            -i /etc/apt/sources.list \
            -i /etc/apt/sources.list.d/ubuntu.sources || true; \
        sed -e "s|dl-cdn.alpinelinux.org|${MIRROR}|g" \
            -i /etc/apk/repositories || true; \
    }

#2
ENV DEBIAN_FRONTEND=noninteractive
RUN echo "**** install essentials ****" && \
    which apt-get && { \
        apt-get update && \
        apt-get install -y \
            wget curl git \
            tar xz-utils lzip unzip zstd \
            build-essential libtool pkg-config \
            automake autoconf gettext autopoint \
            cmake meson \
            nasm yasm bison flex \
            luajit perl libhttp-daemon-perl \
            nodejs python3 moreutils \
            openssh-client rsync \
            ccache distcc \
            && \
        update-distcc-symlinks && \
        apt-get clean && \
        rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/* /var/log/* \
        ; \
    } || { \
        apk update && \
        apk add --no-cache \
            wget curl git \
            tar xz lzip unzip zstd \
            build-base libtool pkgconfig \
            automake autoconf gettext \
            cmake meson \
            nasm yasm bison flex \
            luajit perl perl-http-daemon \
            nodejs python3 moreutils \
            openssh rsync \
            ccache distcc \
            ; \
    }

# ccache: disable by default
ENV USE_CCACHE=0
ENV CCACHE_UMASK=022
ENV CCACHE_DIR=

# distcc
ENV DISTCC_VERBOSE=0
ENV DISTCC_DIR=
ENV DISTCC_OPTS=
ENV DISTCC_HOSTS=

RUN useradd -U -m -s /bin/bash buildbot

RUN echo -e '#!/bin/bash\n\neval -- "$@"\n' > /entrypoint.sh && \
    chmod 0755 /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

ENV BUILDER_NAME=cmdlets-builder
