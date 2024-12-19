# syntax=docker/dockerfile:1

ARG BASEIMAGE=mtdcy/nginx:latest

FROM ${BASEIMAGE}

# labels
LABEL   maintainer="mtdcy.chen@gmail.com"

# prepare nginx-ui
ARG VERSION=2.0.0-beta.42
ARG TARGET=linux-64
ADD https://github.com/0xJacky/nginx-ui/releases/download/v${VERSION}/nginx-ui-${TARGET}.tar.gz /tmp/

#1. always apply MIRROR
#2. install nginx if not exists
ARG MIRROR
RUN \
    echo "**** apply mirrors ****" && \
    test -z "${MIRROR}" || \
        sed -e "s|archive.ubuntu.com|${MIRROR}|g" \
            -e "s|security.ubuntu.com|${MIRROR}|g" \
            -i /etc/apt/sources.list \
            -i /etc/apt/sources.list.d/ubuntu.sources; \
    echo "**** install essentials ****" && \
    apt-get update && \
    { which nginx || apt-get install -y nginx; } && \
    apt-get autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    tar -C /usr/bin -xf /tmp/nginx-ui-* nginx-ui && \
    rm /tmp/nginx-ui-*

# prepare rootfs
ENV NGX_UI_LOGFILE=/var/log/nginx-ui.log
COPY rootfs/ /

# 8080 for mgmt
EXPOSE  80 443 8080
