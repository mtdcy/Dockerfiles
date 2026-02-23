# syntax=docker/dockerfile:1
FROM baseimage:latest

# labels
LABEL maintainer="mtdcy.chen@gmail.com"

ARG MIRROR
ARG TARGETPLATFORM
ARG GO_VER=1.25.1
ARG LUALS_VER=3.15.0

ENV GOPATH=/opt/go
ENV CARGO_INSTALL_ROOT=/opt/cargo
ENV PATH="$GOPATH/bin:$CARGO_INSTALL_ROOT/bin:/usr/local/go/bin:$PATH"

# install dependencies
SHELL ["bash", "-c"]
RUN <<-EOS
    set -ex

    if test -n "$MIRROR"; then
        echo "🟢 setup mirrors 🟢"

        export GOPROXY=$MIRROR/gomods

        mkdir -p $HOME/.cargo
        cat << EOF >> $HOME/.cargo/config.toml
[source.crates-io]
replace-with = 'mirrors'

[source.mirrors]
registry = "sparse+$MIRROR/crates.io-index/"

[registries.mirrors]
index = "sparse+$MIRROR/crates.io-index/"
EOF
    fi

    echo "🟢 install package managers 🟢"

    if which apt-get; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y python3 python3-pip python3-venv npm \
            ccls cargo rustfmt luarocks

        apt-get autoremove
        apt-get clean
        rm -rf /var/lib/apt/lists/*

        # Lua
        luarocks install luacheck
        cargo install stylua --features luajit
    else
        apk update
        apk add --no-cache git python3 py3-pip npm \
            ccls cargo rustfmt luacheck stylua
    fi

    echo "🟢 install latest go 🟢"

    TARGET="linux-amd64"
    case "$TARGETPLATFORM" in
        linux/arm64)    TARGET=linux-arm64 ;;
    esac

    curl -sL https://go.dev/dl/go$GO_VER.$TARGET.tar.gz | tar -C /usr/local -xz

    echo "🟢 install runtimes 🟢"

    # Go
    go install golang.org/x/tools/gopls@latest
    go install golang.org/x/tools/cmd/goimports@latest
    go install github.com/checkmake/checkmake/cmd/checkmake@latest

    echo "🟢 install prebuilts 🟢"
    
    TARGET="linux-x64"
    case "$TARGETPLATFORM" in
        linux/arm64)    TARGET=linux-arm64 ;;
    esac

    mkdir -p /usr/local/bin
    curl -sL https://github.com/LuaLS/lua-language-server/releases/download/$LUALS_VER/lua-language-server-$LUALS_VER-$TARGET.tar.gz | tar -C /usr/local/ -xz bin/lua-language-server

    echo "🟢 remove caches 🟢"

    rm -rf $HOME/.cache
    rm -rf $HOME/.config/go
    rm -rf $HOME/.luarocks
    rm -rf $HOME/.cargo

    rm -rf /opt/go/pkg
EOS

RUN <<-EOS
    set -ex
    echo "🟢 install nvim 🟢"

    if curl --fail -sIL https://git.mtdcy.top -o /dev/null; then
        git clone https://git.mtdcy.top:8443/mtdcy/pretty.nvim.git /opt/nvim --depth=1
    else
        git clone https://github.com/mtdcy/pretty.nvim.git /opt/nvim --depth=1
    fi

    cd /opt/nvim

    ./install.sh --no-update

    echo "🟢 remove caches 🟢"

    rm -rf $HOME/.cache
    rm -rf $HOME/.npm

    rm -rf .git
    
    echo "🟢 add user nvim 🟢"

    useradd -U -m -s /bin/bash nvim

    sudo -u nvim nvim -c 'packloadall | silent! helptags ALL | UpdateRemotePlugins' +quit
EOS

COPY entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
