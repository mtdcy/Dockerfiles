# syntax=docker/dockerfile:1
ARG BASEIMAGE=ubuntu:latest

# download or build using stage
FROM alpine:3 AS stage

WORKDIR /rootfs

# prepare tools
ARG MIRROR
RUN test -n "${MIRROR}" && \
        sed -e "s|dl-cdn.alpinelinux.org|${MIRROR}|g" \
            -i /etc/apk/repositories || true
RUN apk add --no-cache curl xz

# prepare s6
ARG S6_VERSION=3.1.6.2
ARG S6_ARCH=x86_64

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C /rootfs -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-${S6_ARCH}.tar.xz /tmp
RUN tar -C /rootfs -Jxpf /tmp/s6-overlay-${S6_ARCH}.tar.xz

# s6 optional symlinks
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-symlinks-noarch.tar.xz /tmp
RUN tar -C /rootfs -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-symlinks-arch.tar.xz /tmp
RUN tar -C /rootfs -Jxpf /tmp/s6-overlay-symlinks-arch.tar.xz

FROM ${BASEIMAGE}
# labels
LABEL maintainer="mtdcy.chen@gmail.com"

# ENV & ARG
ARG TZ=Asia/Shanghai

ENV TZ=${TZ}
ENV DEBIAN_FRONTEND=noninteractive

ARG MIRROR
RUN test -z "${MIRROR}" || \
        sed -e "s|archive.ubuntu.com|${MIRROR}|g" \
            -e "s|security.ubuntu.com|${MIRROR}|g" \
            -i /etc/apt/sources.list \
            -i /etc/apt/sources.list.d/ubuntu.sources

RUN \
    echo "**** install packages ****" && \
        apt-get update && \
        apt-get install -y \
            locales tzdata \
            wget curl \
            xz-utils zstd \
            procps \
            iputils-ping \
            bind9-dnsutils \
            && \
    echo "**** generate locale ****" && \
        locale-gen en_US.UTF-8 && \
    echo "**** setup timezone ****" && \
        ln -svf /usr/share/zoneinfo/$TZ /etc/localtime && \
        echo "$TZ" > /etc/timezone && \
    echo "**** cleanup ****" && \
        apt-get autoremove && \
        apt-get clean && \
        rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/* /var/log/*

# s6: strange behavior
ENV S6_KEEP_ENV=1
COPY --from=stage /rootfs/ /
ENTRYPOINT ["/init"]
