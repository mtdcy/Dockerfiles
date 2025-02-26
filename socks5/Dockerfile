# syntax=docker/dockerfile:1
ARG BASEIMAGE
FROM ${BASEIMAGE:-alpine:3}

# lables
LABEL maintainer="mtdcy.chen@gmail.com"

ARG VERSION=0.1
RUN \
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
