# syntax=docker/dockerfile:1

FROM    mtdcy/alpine:latest
LABEL   maintainer="mtdcy.chen@gmail.com"

# upstream dns server
ENV DNSMASQ_SERVERS=
ENV DNSMASQ_DHCP_ROUTER=
ENV DNSMASQ_DHCP_SERVERS=
ENV DNSMASQ_OPTS=

RUN apk add --no-cache dnsmasq-dnssec

EXPOSE 53 53/udp 67/udp

VOLUME /config

COPY entrypoint.sh /
RUN chmod a+x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
