# syntax=docker/dockerfile:1
ARG BASEIMAGE=ubuntu:latest

FROM ${BASEIMAGE}

# labels
LABEL   maintainer="mtdcy.chen@gmail.com"

## prepare ##
ARG VERSION=0.1
ENV DEBIAN_FRONTEND=noninteractive

#1. no p910nd in alpine
#2. single printer per container
RUN apt-get update -y &&                                             \
    apt-get install -y p910nd &&                                     \
    sed -e 's@^P910ND_START=.*$@P910ND_START="1"@'                   \
        -e 's@^P910ND_NUM=.*@P910ND_NUM="0"@'                        \
        -e 's@^P910ND_OPTS=.*$@P910ND_OPTS="-f /dev/usb/lp0 -b -d"@' \
        -i /etc/default/p910nd &&                                    \
    rm -rf /var/lib/apt/lists/*

EXPOSE 9100

CMD ["/etc/init.d/p910nd", "start"]
