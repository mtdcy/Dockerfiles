# syntax=docker/dockerfile:1

FROM    mtdcy/alpine:latest
LABEL   maintainer="mtdcy.chen@gmail.com"

ENV SSH_HOST=""
ENV SSH_BIND=""
ENV SSH_IDENT="/config/ssh_id_rsa"
ENV SSH_CONFIG="/config/ssh_config"
ENV SSH_OPTS="UserKnownHostsFile=/config/ssh_known_hosts"

RUN apk add --no-cache openssh-client-default

EXPOSE 1070

VOLUME /config

COPY socks5.sh /

CMD ["/socks5.sh", "verbose"]
