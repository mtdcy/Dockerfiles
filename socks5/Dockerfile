# syntax=docker/dockerfile:1
ARG BASEIMAGE=alpine:3

# download or build using stage
FROM ${BASEIMAGE}

# lables
LABEL maintainer="mtdcy.chen@gmail.com"

#1. always apply MIRROR
ARG MIRROR
RUN \
    echo "**** apply mirrors ****" && \
    test -n "${MIRROR}" && { \
        sed -e "s|archive.ubuntu.com|${MIRROR}|g" \
            -e "s|security.ubuntu.com|${MIRROR}|g" \
            -i /etc/apt/sources.list \
            -i /etc/apt/sources.list.d/ubuntu.sources || true; \
        sed -e "s|dl-cdn.alpinelinux.org|${MIRROR}|g" \
            -i /etc/apk/repositories || true; \
    }; \
    echo "**** install essentials ****" && \
    which apt-get && { \
        apt-get update && \
        apt-get install -y openssh-client \
        ; \
    } || { \
        apk add --no-cache openssh-client-default \
        ; \
    }

ENV SSH_HOST=""
ENV SSH_BIND=""
ENV SSH_IDENT="/config/ssh_id_rsa"
ENV SSH_CONFIG="/config/ssh_config"
ENV SSH_OPTS="UserKnownHostsFile=/config/ssh_known_hosts"

EXPOSE 1070

VOLUME /config

COPY rootfs/ /

CMD ["/socks5.sh", "verbose"]
