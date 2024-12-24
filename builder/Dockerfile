# syntax=docker/dockerfile:1
ARG BASEIMAGE

FROM ${BASEIMAGE:-ubuntu:latest}

# labels
LABEL maintainer="mtdcy.chen@gmail.com"

# install packages
RUN echo "**** install essentials ****" && \
    which apt-get && { \
        export DEBIAN_FRONTEND=noninteractive && \
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
        rm -rf /var/lib/apt/lists/* /var/tmp/* /var/log/* \
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

# override entrypoint
RUN echo -e '#!/bin/bash\n\neval -- "$@"\n' > /entrypoint.sh && \
    chmod 0755 /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

ENV BUILDER_NAME=cmdlets-builder
