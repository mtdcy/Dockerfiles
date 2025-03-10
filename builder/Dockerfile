# syntax=docker/dockerfile:1
FROM ubuntu:latest AS stage

ARG GO_VERSION=1.23.6

SHELL ["/bin/bash", "-c"]
RUN <<-EOS
    set -ex
    HOST=$(uname -s)
    case "$(uname -m)" in
        aarch64)    ARCH=arm64 ;;
        *)          ARCH=amd64 ;;
    esac

    cd /tmp
    wget https://go.dev/dl/go$GO_VERSION.${HOST,,}-$ARCH.tar.gz
    tar -C /usr/local -xvf /tmp/*.tar.gz
EOS

FROM ubuntu:latest

# labels
LABEL maintainer="mtdcy.chen@gmail.com"

COPY --from=stage /usr/local/go /usr/local/
ENV PATH="/usr/local/go/bin:$PATH"

# install packages
SHELL ["/bin/bash", "-c"]
RUN <<-EOS
    set -ex
    echo "**** install essentials ****"

    if which apt-get; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
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
            cargo
        update-distcc-symlinks
        apt-get clean
        rm -rf /var/lib/apt/lists/* /var/tmp/* /var/log/*
    else
        apk update
        apk add --no-cache \
            grep sed gawk \
            wget curl git diffutils findutils ncurses \
            tar gzip xz lzip unzip zstd \
            linux-headers build-base libtool pkgconfig \
            automake autoconf gettext \
            cmake meson \
            nasm yasm bison flex \
            luajit perl perl-http-daemon \
            nodejs python3 moreutils \
            openssh rsync \
            ccache distcc \
            cargo
    fi

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
