# syntax=docker/dockerfile:1

FROM baseimage:latest AS builder

ARG NODE_VERSION=v24
ARG GO_VERSION=1.26.7
ARG RUST_VERSION=1.98.0

ARG MIRROR
ARG TARGETPLATFORM

COPY --chmod=0755 entrypoint.sh /opt/

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
        # LTS: v24
        IFS=' ' read -r version _ < <(curl -sL https://nodejs.org/dist/index.tab | grep -oE "^$NODE_VERSION[0-9.]+" -m1)
        case "$TARGETPLATFORM" in
          linux/arm64)
            curl -fsSL "https://nodejs.org/dist/$version/node-$version-linux-arm64.tar.xz" | tar -xJ --strip-components=1
          ;;
          linux/amd64)
            curl -fsSL "https://nodejs.org/dist/$version/node-$version-linux-x64.tar.xz" | tar -xJ --strip-components=1
          ;;
        esac
    fi
EOS

RUN <<-EOS
    echo "**** setup golang ****"
    #goversion=$(curl -s "https://go.dev/VERSION?m=text" | grep "^go")
    curl -fsSL https://go.dev/dl/go$GO_VERSION.${TARGETPLATFORM//\//-}.tar.gz | tar -xz
EOS

RUN <<-EOS
    echo "**** setup rust ****"
    if test -n "${MIRROR}"; then
        export RUSTUP_DIST_SERVER=$MIRROR/rust-static
        export RUSTUP_UPDATE_ROOT=$MIRROR/rust-static/rustup
    fi

    /tmp/rustup-init.sh -y --no-modify-path     \
        --profile minimal                       \
        --default-toolchain $RUST_VERSION

    rustup target add --toolchain=$RUST_VERSION $(uname -m)-unknown-linux-musl
EOS

# musl-gcc.sh has no version control yet
ARG CACHEBUST
RUN <<-EOS
    echo "**** setup musl-gcc ****"
    /tmp/musl-gcc.sh

    # remove share libraries if static one exists
    while read -r so; do
        [[ "$so" =~ libc.so$ ]] && continue

        if test -f "${so/%.so/.a}"; then
            rm -fv "$so"*
        fi
    done < <(find /opt/$(uname -m)-linux-musl -name "*.so")

    find /opt -name "*.la" -exec rm -rf {} \;
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
            libssl-dev
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
            openssl-dev
    fi

    echo "**** install latest meson ****"
    python3 -m pip install --upgrade pip || true
    # --break-system-packages: This environment is externally managed
    python3 -m pip install --upgrade meson --break-system-packages
    rm -rf "$HOME/.cache" || true
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

# override entrypoint
ENTRYPOINT ["/opt/entrypoint.sh"]

ARG TARGETPLATFORM
ENV BUILDER_NAME="$TARGETPLATFORM"
