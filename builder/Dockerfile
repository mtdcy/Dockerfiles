# syntax=docker/dockerfile:1

FROM baseimage:latest AS builder

ARG MIRROR
ARG TARGETPLATFORM

COPY ./resources/${TARGETPLATFORM}/* /tmp/
ENV RUSTUP_HOME="/opt/rust"
ENV CARGO_HOME="/opt/rust/cargo"
ENV PATH="$CARGO_HOME/bin:/opt/go/bin:/opt/bin:$PATH"

WORKDIR /opt/
RUN <<-EOS
    set -ex
    ls -lh /tmp/

    echo "**** setup nodejs ****"
    # node prebuilts only for glibc
    if ldd --version | grep GLIBC; then
        tar --strip-components=1 -xf /tmp/node-v*.tar.xz
    fi

   #echo "**** setup musl toolcahin ****"
   #tar --strip-components=1 -xf /tmp/$(uname -m)-linux-musl-native.tgz

   #mkdir -pv /lib/$(uname -m)-linux-musl
   #ln -sfv /opt/lib/libgcc_s.* /lib/$(uname -m)-linux-musl/
   ## fails on alpine-3, why?
   #ldconfig || true

    echo "**** setup golang ****"
    tar -xf /tmp/go*.tar.gz

    echo "**** setup rust ****"
    if test -n "${MIRROR}"; then
        export RUSTUP_DIST_SERVER=$MIRROR/rust-static
        export RUSTUP_UPDATE_ROOT=$MIRROR/rust-static/rustup
    fi

    /tmp/rustup-init.sh -y --no-modify-path
    
    echo "**** setup env ****"
    echo "export CARGO_HOME=$CARGO_HOME"   >> .env
    echo "export RUSTUP_HOME=$RUSTUP_HOME" >> .env
    echo "export PATH=$PATH"               >> .env
EOS


FROM baseimage:latest

# labels
LABEL maintainer="mtdcy.chen@gmail.com"

WORKDIR /opt/
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
            cmake meson texinfo \
            nasm yasm bison flex \
            luajit perl libhttp-daemon-perl \
            python3 moreutils \
            openssh-client rsync \
            ccache distcc
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
            ccache distcc
    fi
EOS

# nodejs path
ENV PATH="/opt/bin:$PATH" 

COPY --from=builder /opt /opt
RUN <<-EOS
    set -ex
    echo "**** post setup ****"

    # setup env
    . /opt/.env

   #mkdir -pv /lib/$(uname -m)-linux-musl
   #ln -sfv /opt/lib/libgcc_s.* /lib/$(uname -m)-linux-musl/
    # fails on alpine-3, why?
    ldconfig || true

    node --version
    gcc --version
    go version
    cargo --version
    rustc --version

    # delete default user(1000)
    userdel ubuntu || true
    useradd -U -m -s /bin/bash buildbot

    # no passwd for buildbot
    echo "buildbot ALL=(ALL) NOPASSWD:ALL"  >> /etc/sudoers
    
    # keep env PATH
    sed -i '/env_reset/ s/^/# &/g' /etc/sudoers
    echo "Defaults !env_reset"              >> /etc/sudoers
    echo "Defaults env_keep += \"PATH\""    >> /etc/sudoers

    sed -i '/secure_path/ s/^/# &/g' /etc/sudoers
    echo "Defaults secure_path=\"$PATH\""   >> /etc/sudoers
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
