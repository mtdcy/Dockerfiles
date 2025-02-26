# syntax=docker/dockerfile:1
ARG BASEIMAGE
FROM ${BASEIMAGE:-ubuntu:latest} AS stage

ADD https://go.dev/dl/go1.23.6.linux-amd64.tar.gz /tmp/
RUN tar -C /usr/local -xvf /tmp/go1.23.6.linux-amd64.tar.gz

ARG BASEIMAGE
FROM ${BASEIMAGE:-ubuntu:latest}

# labels
LABEL maintainer="mtdcy.chen@gmail.com"

# install packages
RUN echo "**** install essentials ****" && \
        export DEBIAN_FRONTEND=noninteractive && \
        apt-get update && \
        apt-get install -y \
            wget curl git diffutils findutils ncurses-bin \
            tar gzip xz-utils lzip unzip zstd \
            build-essential libtool pkg-config \
            automake autoconf gettext autopoint \
            cmake meson \
            nasm yasm bison flex \
            luajit perl libhttp-daemon-perl \
            nodejs python3 moreutils \
            openssh-client rsync \
            ccache distcc \
            cargo \
            && \
        update-distcc-symlinks && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/* /var/tmp/* /var/log/*

COPY --from=stage /usr/local/go /usr/local/
ENV PATH="/usr/local/go/bin:$PATH"

# add Implib.so
RUN git clone --depth=1 https://github.com/yugr/Implib.so /opt/Implib.so
COPY --chmod=0755 Implib.so /usr/bin/

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
COPY --chmod=0755 entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]

ENV BUILDER_NAME=cmdlets-builder
