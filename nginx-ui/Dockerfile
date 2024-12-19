# syntax=docker/dockerfile:1

ARG BASEIMAGE=mtdcy/nginx:latest

FROM ${BASEIMAGE}

# labels
LABEL   maintainer="mtdcy.chen@gmail.com"

# always apply MIRROR
ARG MIRROR
RUN test -z "${MIRROR}" || \
        sed -e "s|archive.ubuntu.com|${MIRROR}|g" \
            -e "s|security.ubuntu.com|${MIRROR}|g" \
            -i /etc/apt/sources.list \
            -i /etc/apt/sources.list.d/ubuntu.sources

# install nginx if not exists
RUN \
    apt-get update && \
    echo "**** install essentials ****" && \
    { which nginx || apt-get install -y nginx; } && \
    apt-get autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ARG VERSION=2.0.0-beta.42
ARG TARGET=linux-64

ADD https://github.com/0xJacky/nginx-ui/releases/download/v${VERSION}/nginx-ui-${TARGET}.tar.gz /tmp/
RUN tar -C /usr/bin -xf /tmp/nginx-ui-* nginx-ui && rm /tmp/nginx-ui-*

# 8080 for mgmt
EXPOSE  80 443 8080

ENV NGX_UI_LOGFILE=/var/log/nginx-ui.log

ADD --chmod=0644 nginx-ui.conf /etc/nginx/conf.d/
ADD --chmod=0755 nginx-ui.sh /entrypoint.d/
# if entrypoint.d is not supported, start container with cmd: /entrypoint.d/nginx-ui.sh
