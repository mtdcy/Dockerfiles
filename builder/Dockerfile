# syntax=docker/dockerfile:1
FROM baseimage:latest

# labels
LABEL maintainer="mtdcy.chen@gmail.com"

ENV PATH="/usr/local/go/bin:$PATH"

ARG NODE_VERSION=22.20.0

# install packages
SHELL ["/bin/bash", "-c"]
RUN <<-EOS
    set -ex
    echo "**** install essentials ****"

    if which apt-get; then
        export DEBIAN_FRONTEND=noninteractive

        # PPA: go & nodejs
        apt-get update && apt-get install -y software-properties-common # install add-apt-repository
        add-apt-repository ppa:longsleep/golang-backports
        curl -sL https://deb.nodesource.com/setup_22.x | bash -

        apt-get update
        apt-get install -y \
            wget curl git diffutils findutils ncurses-bin \
            tar gzip xz-utils lzip unzip zstd \
            build-essential libtool pkg-config \
            automake autoconf gettext autopoint \
            cmake meson texinfo \
            nasm yasm bison flex \
            luajit perl libhttp-daemon-perl \
            python3 moreutils \
            openssh-client rsync \
            ccache distcc \
            golang-go cargo nodejs

        update-distcc-symlinks
        apt-get clean
        rm -rf /var/lib/apt/lists/* /var/tmp/* /var/log/*
    else
        apk update
        apk add --no-cache \
            grep sed gawk coreutils \
            wget curl git diffutils findutils ncurses \
            tar gzip xz lzip unzip zstd \
            linux-headers build-base libtool pkgconfig \
            automake autoconf gettext \
            cmake meson texinfo \
            nasm yasm bison flex \
            luajit perl perl-http-daemon \
            nodejs python3 moreutils \
            openssh rsync \
            ccache distcc \
            go cargo
    fi

    go version
    node --version

    echo "**** post setup ****"
    # delete default user(1000)
    userdel ubuntu || true
    useradd -U -m -s /bin/bash buildbot
EOS

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

# override entrypoint
COPY --chmod=0755 entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]

ENV BUILDER_NAME=cmdlets-builder
