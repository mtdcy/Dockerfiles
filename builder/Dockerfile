# syntax=docker/dockerfile:1

FROM baseimage:latest AS builder

ARG NODE_VERSION=v24
ARG GO_VERSION=1.26.7
ARG ZIG_VERSION=0.16.0

ARG MIRROR
ARG ZIG_MIRROR
ARG TARGETPLATFORM

COPY --chmod=0755 entrypoint.sh /opt/

COPY ./scripts/* /tmp/

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
    export CARGO_HOME=/opt/cargo
    export RUSTUP_HOME=/opt/rustup
    export PATH="$CARGO_HOME/bin:$PATH"

    if test -n "$MIRROR"; then
        export RUSTUP_DIST_SERVER=$MIRROR/rust-static
        export RUSTUP_UPDATE_ROOT=$MIRROR/rust-static/rustup
    fi

    /tmp/rustup-init.sh -y --no-modify-path --default-toolchain none
EOS

RUN <<-EOS
    echo "**** setup zig ****"

    case "$TARGETPLATFORM" in
        linux/arm64)    ZIG_ARCH=aarch64-linux  ;;
        *)              ZIG_ARCH=x86_64-linux   ;;
    esac

    if test -n "$ZIG_MIRROR"; then
        ZIG_URL=$MIRROR/zig-$ZIG_ARCH-$ZIG_VERSION.tar.xz
        curl -fsIL "$ZIG_URL" -o /dev/null || unset ZIG_URL
    fi

    test -n "$ZIG_URL" || ZIG_URL=https://ziglang.org/download/$ZIG_VERSION/zig-$ZIG_ARCH-$ZIG_VERSION.tar.xz

    mkdir -pv /opt/zig
    curl -fsSL "$ZIG_URL" | tar -C /opt/zig --strip-components=1 -xJ
EOS



# musl-gcc.sh has no version control yet
ARG CACHEBUST
RUN <<-EOS
    echo "**** setup musl-gcc ****"
    TARGET="$(uname -m)-linux-musl"

    if curl -fsSI --connect-timeout 1 https://gitea.mtdcy.top -o /dev/null; then
        url=https://gitea.mtdcy.top:8443/mtdcy/musl-gcc-build/releases/download/latest/$TARGET.tar.xz
    else
        url=https://github.com/mtdcy/musl-gcc-build/releases/latest/download/$TARGET.tar.xz
    fi

    curl -fsSL "$url" -o /tmp/$(basename $url)
    tar -C /opt -xf /tmp/$(basename $url)

    # remove share libraries if static one exists
    while read -r so; do
        [[ "$so" =~ libc.so$ ]] && continue

        test -f "${so/%.so/.a}" && rm -fv "$so"* || true
    done < <(find /opt/$TARGET -name "*.so")

    find /opt/$TARGET -name "*.la" -exec rm -rf {} +
EOS

FROM baseimage:latest

# labels
LABEL maintainer="mtdcy.chen@gmail.com"

ARG MIRROR=https://mirrors.mtdcy.top

WORKDIR /opt/
SHELL ["/bin/bash", "-ex", "-o", "pipefail", "-c"]

RUN <<-EOS
    echo "**** install essentials ****"

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
        libssl-dev gperf llvm
    apt-get clean
    rm -rf /var/lib/apt/lists/* /var/tmp/* /var/log/*

    echo "**** install latest meson ****"
    python3 -m pip install --upgrade pip || true
    # --break-system-packages: This environment is externally managed
    python3 -m pip install --upgrade meson --break-system-packages
    rm -rf "$HOME/.cache" || true
EOS

# install build tools like go/rust from stage-1 builder
COPY --from=builder /opt /opt

# must set these ENVs explicitly, or run container with --entrypoint='' will have problem
ENV GOROOT="/opt/go"
ENV CARGO_HOME="/opt/cargo"
ENV RUSTUP_HOME="/opt/rustup"
ENV PATH="$CARGO_HOME/bin:$GOROOT/bin:/opt/zig:/opt/bin:$PATH"

# override entrypoint
ENTRYPOINT ["/opt/entrypoint.sh"]
# final setup: ubuntu

ARG RUST_VERSION=1.98.0
RUN <<-EOS
    echo "**** post setup ****"

    if test -d /opt/$(uname -m)-linux-musl; then
        # fix ld-musl
        ln -sfv $(find /opt -name libc.so) /lib/ld-musl-$(uname -m).so.1

        # hack libgcc_s.a => some build system like rustc won't search for libgcc.a
        ln -sfv libgcc.a $(find /opt/ -name libgcc.a | sed 's/libgcc.a$/libgcc_s.a/')

        # fix LD_LIBRARY_PATH
        echo /opt/$(uname -m)-linux-musl/lib > /etc/ld.so.conf.d/$(uname -m)-linux-musl.conf
    fi

    # fails on alpine-3, why?
    ldconfig || true

    # testing
    ldconfig -p | grep libc.so
    ldconfig -p | grep libgcc_s.so

    node --version
    gcc --version
    go version

    which zig && zig version || true

    if which rustup; then
        if test -n "$MIRROR"; then
            export RUSTUP_DIST_SERVER=$MIRROR/rust-static
            export RUSTUP_UPDATE_ROOT=$MIRROR/rust-static/rustup
        fi

        # install toolchain and target(s)
        rustup toolchain install $RUST_VERSION \
            --default \
            --profile minimal \
            --target $(uname -m)-unknown-linux-gnu \
            --target $(uname -m)-unknown-linux-musl \
        
        rustup show

        rustc --version
        cargo --version
    fi

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

ARG TARGETPLATFORM
ENV BUILDER_NAME="$TARGETPLATFORM"
