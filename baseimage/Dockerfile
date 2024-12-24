# syntax=docker/dockerfile:1
ARG BASEIMAGE=ubuntu:24.04

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

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-noarch.tar.xz \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-${S6_ARCH}.tar.xz \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-symlinks-noarch.tar.xz \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-symlinks-arch.tar.xz /tmp

RUN find /tmp -name "s6-overlay-*" -exec tar -C /rootfs -Jxpf {} \; && \
    du -a -h | tee /rootfs/installed-files

FROM ${BASEIMAGE}
# labels
LABEL maintainer="mtdcy.chen@gmail.com"

# ENV & ARG
ARG TZ=Asia/Shanghai

ENV TZ=${TZ}
ENV DEBIAN_FRONTEND=noninteractive

ARG MIRROR
RUN \
    echo "**** apply mirrors ****" && \
    test -n "${MIRROR}" && { \
        sed -e "s|archive.ubuntu.com|${MIRROR}|g" \
            -e "s|security.ubuntu.com|${MIRROR}|g" \
            -i /etc/apt/sources.list \
            -i /etc/apt/sources.list.d/* || true; \
        sed -e "s|dl-cdn.alpinelinux.org|${MIRROR}|g" \
            -i /etc/apk/repositories || true; \
    }

RUN \
    echo "**** install essentials ****" && \
    which apt-get && { \
        apt-get update && \
        apt-get install -y \
            bash locales tzdata \
            wget curl \
            tar xz-utils zstd lzip \
            procps \
            iputils-ping \
            bind9-dnsutils \
            && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/* /var/tmp/* /var/log/* && \
        locale-gen en_US.UTF-8; \
    } || { \
        apk add --no-cache \
            bash shadow \
            musl-locales tzdata \
            wget curl \
            tar xz zstd lzip \
            procps \
            iputils \
            bind-tools \
            && \
        /usr/glibc-compat/bin/localdef -i en_US -f UTF-8 en_US.UTF-8; \
    }; \
    echo "**** post setup ****" && \
        ln -svf /usr/share/zoneinfo/$TZ /etc/localtime && \
        echo "$TZ" > /etc/timezone

# s6: strange behavior
ENV S6_KEEP_ENV=1

COPY --from=stage /rootfs/ /

ENTRYPOINT ["/init"]
