# syntax=docker/dockerfile:1

FROM baseimage:latest AS builder

ARG MIRROR
ARG TARGETPLATFORM
# no cache for this stage
ARG CACHEBUST=1

# add Implib.so
COPY --chmod=0755 Implib.so /opt/bin/
COPY --chmod=0755 entrypoint.sh /opt/

COPY ./resources/${TARGETPLATFORM}/* /tmp/
COPY ./scripts/* /tmp/

ENV GOROOT="/opt/go"
ENV RUSTUP_HOME="/opt/rustup"
ENV CARGO_HOME="/opt/cargo"
ENV PATH="$CARGO_HOME/bin:$GOROOT/bin:/opt/bin:$PATH"

WORKDIR /opt/

SHELL ["/bin/bash", "-ex", "-o", "pipefail", "-c"]
RUN <<-EOS
    echo "**** setup nodejs ****"
    # node prebuilts only for glibc
    if ldd --version | grep GLIBC; then
        tar --strip-components=1 -xf /tmp/node-v*.tar.xz
    fi

    echo "**** setup musl-gcc ****"
    /tmp/musl-gcc.sh

    find /opt -name "*.la" -exec rm -rf {} \;

    echo "**** setup golang ****"
    tar -xf /tmp/go*.tar.gz

    echo "**** setup rust ****"
    if test -n "${MIRROR}"; then
        export RUSTUP_DIST_SERVER=$MIRROR/rust-static
        export RUSTUP_UPDATE_ROOT=$MIRROR/rust-static/rustup
    fi

    /tmp/rustup-init.sh -y --no-modify-path     \
        --profile minimal                       \
        --default-toolchain stable

    rustup target add $(uname -m)-unknown-linux-musl
EOS


FROM baseimage:latest

# labels
LABEL maintainer="mtdcy.chen@gmail.com"

WORKDIR /opt/
SHELL ["/bin/bash", "-ex", "-o", "pipefail", "-c"]
RUN <<-EOS
    echo "**** install essentials ****"

    if which apt-get; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y \
            wget curl git diffutils findutils ncurses-bin \
            tar gzip xz-utils lzip unzip zstd \
            build-essential libtool pkg-config \
            automake autoconf gettext autopoint \
            cmake meson texinfo moreutils \
            nasm yasm bison flex \
            luajit perl libhttp-daemon-perl \
            python3 python3-pip python3-venv \
            openssh-client rsync \
            ccache distcc \
            libssl-dev
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
            cmake meson texinfo moreutils \
            nasm yasm bison flex \
            luajit perl perl-http-daemon \
            nodejs python3 py3-pip python3-dev \
            openssh rsync \
            ccache distcc \
            openssl-dev
    fi

    echo "**** install latest meson ****"
    python3 -m pip install --upgrade pip || true
    # --break-system-packages: This environment is externally managed
    python3 -m pip install --upgrade meson --break-system-packages
    rm -rf "$HOME/.cache" || true

    # Implib.so
    git clone --depth=1 https://github.com/yugr/Implib.so /opt/Implib.so
EOS

COPY --from=builder /opt /opt

# must set these ENVs explicitly, or run container with --entrypoint='' will have problem
ENV GOROOT="/opt/go"
ENV RUSTUP_HOME="/opt/rustup"
ENV CARGO_HOME="/opt/cargo"
ENV PATH="$CARGO_HOME/bin:$GOROOT/bin:/opt/bin:$PATH"

RUN <<-EOS
    echo "**** post setup ****"

    # fix ld-musl
    ln -sfv $(find /opt -name libc.so) /lib/ld-musl-$(uname -m).so.1

    # hack libgcc_s.a => some build system like rustc won't search for libgcc.a
    ln -sfv libgcc.a $(find /opt/ -name libgcc.a | sed 's/libgcc.a$/libgcc_s.a/')

    # fix LD_LIBRARY_PATH
    echo /opt/$(uname -m)-linux-musl/lib > /etc/ld.so.conf.d/$(uname -m)-linux-musl.conf

    # fails on alpine-3, why?
    ldconfig || true

    # testing
    ldconfig -p | grep libc.so
    ldconfig -p | grep libgcc_s.so

    node --version
    gcc --version
    go version
    cargo --version
    rustc --version

    # install tools
    cargo install toml2json cargo-c

    rm -rf $CARGO_HOME/registry
    rm -rf $CARGO_HOME/*-cache

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

    echo 'PS1="[\e[31m${BUILDER_NAME}\e[m] \e[34m\w \e[32m\$\e[m "' >> /home/buildbot/.bashrc
EOS

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
ENTRYPOINT ["/opt/entrypoint.sh"]

ARG TARGETPLATFORM
ENV BUILDER_NAME="$TARGETPLATFORM"
