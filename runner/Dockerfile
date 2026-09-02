# syntax=docker/dockerfile:1

FROM baseimage:latest

# labels
LABEL maintainer="mtdcy.chen@gmail.com"

ARG MIRROR=https://mirrors.mtdcy.top
ARG NODE_VERSION=v24
ARG TARGETPLATFORM

# must set these ENVs explicitly, or run container with --entrypoint='' will have problem
ENV PATH="/opt/bin:$PATH"

SHELL ["/bin/bash", "-ex", "-o", "pipefail", "-c"]

RUN <<-EOS
    echo "**** setup nodejs ****"

    if node --version | grep "$NODE_VERSION"; then
        echo "node $(node --version) exists"
    else
        pushd /opt

        # node prebuilts only for glibc
        IFS=' ' read -r version _ < <(curl -sL https://nodejs.org/dist/index.tab | grep -oE "^$NODE_VERSION[0-9.]+" -m1)
        case "$TARGETPLATFORM" in
          linux/arm64)
            curl -fsSL "https://nodejs.org/dist/$version/node-$version-linux-arm64.tar.xz" | tar -xJ --strip-components=1
          ;;
          linux/amd64)
            curl -fsSL "https://nodejs.org/dist/$version/node-$version-linux-x64.tar.xz" | tar -xJ --strip-components=1
          ;;
        esac

        popd
    fi

    echo "**** post setup ****"

    # fails on alpine-3, why?
    ldconfig || true
    
    case "$(grep "^ID=.*" /etc/os-release)" in
        ID=fedora)
            # fix exec: "/bin/sleep": stat /bin/sleep: no such file or directory
            test -e /bin/sleep || ln -sfv $(which sleep) /bin/sleep
            test -e /bin/bash  || ln -sfv $(which bash) /bin/bash
            ;;
    esac

    node --version

    # delete default user(1000)
    userdel ubuntu || true
    useradd -U -m -s /bin/bash bot

    # no passwd for bot
    echo "bot ALL=(ALL) NOPASSWD:ALL"  >> /etc/sudoers

    # keep env PATH
    sed -i '/env_reset/ s/^/# &/g' /etc/sudoers
    echo "Defaults !env_reset"              >> /etc/sudoers
    echo "Defaults env_keep += \"PATH\""    >> /etc/sudoers

    sed -i '/secure_path/ s/^/# &/g' /etc/sudoers
    echo "Defaults secure_path=\"$PATH\""   >> /etc/sudoers
EOS
