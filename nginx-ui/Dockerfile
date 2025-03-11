# syntax=docker/dockerfile:1
FROM nginx:latest

# labels
LABEL   maintainer="mtdcy.chen@gmail.com"

ARG VERSION=2.0.0-rc.4

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN <<-EOS
    set -ex
    echo "**** download nginx-ui prebuilts ****"

    case "$(uname -m)" in
        aarch64)    ARCH=arm32-v7a ;; # no arm64 prebuilts
        *)          ARCH=64 ;;
    esac

    cd /tmp
    wget https://github.com/0xJacky/nginx-ui/releases/download/v${VERSION}/nginx-ui-linux-${ARCH}.tar.gz
    tar -C /usr/bin -xf /tmp/nginx-ui-*.tar.gz nginx-ui
    rm /tmp/nginx-ui-*
EOS

# prepare rootfs
ENV NGX_UI_LOGFILE=/var/log/nginx-ui.log
COPY rootfs/ /

# 8080 for mgmt
EXPOSE  80 443 8080
