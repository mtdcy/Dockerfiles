# syntax=docker/dockerfile:1

ARG BASEIMAGE=ubuntu:latest

FROM ${BASEIMAGE} AS builder

ARG NGX_VERSION=1.25.1
ARG NGX_CONNECT=0.0.7
ARG NGX_GEOIP2=3.4

# always apply MIRROR
ARG MIRROR
RUN test -n "${MIRROR}" && { \
        sed -e "s|archive.ubuntu.com|${MIRROR}|g" \
            -e "s|security.ubuntu.com|${MIRROR}|g" \
            -i /etc/apt/sources.list.d/ubuntu.sources || true; \
        sed -e "s|dl-cdn.alpinelinux.org|${MIRROR}|g" \
            -i /etc/apk/repositories || true; \
    }

ADD https://github.com/leev/ngx_http_geoip2_module/archive/${NGX_GEOIP2}.tar.gz \
    https://github.com/chobits/ngx_http_proxy_connect_module/archive/v${NGX_CONNECT}.tar.gz \
    http://nginx.org/download/nginx-${NGX_VERSION}.tar.gz \
    /tmp/build/

WORKDIR /rootfs

RUN \
    which apt-get && { \
        apt-get update && \
        apt-get install -y \
            build-essential \
            zlib1g-dev \
            libxslt1-dev \
            libssl-dev \
            libpcre3-dev   \
            libmaxminddb-dev \
            libxslt-dev \
            libgd-dev \
            libgeoip-dev \
            libperl-dev \
            ; \
    } || { \
        apk add --no-cache \
            build-base \
            openssl-dev \
            pcre-dev \
            zlib-dev \
            libmaxminddb-dev \
            libxslt-dev \
            gd-dev \
            geoip-dev \
            perl-dev \
            ; \
    } && \
    cd /tmp/build && \
    find . -name "*.tar.gz" -exec tar -xf {} \; && \
    cd nginx-${NGX_VERSION} && \
    case "${NGX_VERSION}" in \
        1.24.*|1.25.*|1.26.*|1.27.*) \
            patch -p1 < ../ngx_http_proxy_connect_module-${NGX_CONNECT}/patch/proxy_connect_rewrite_102101.patch;; \
    esac && \
    ./configure \
        --with-cc-opt='-g -O2 -flto=auto -ffat-lto-objects -flto=auto -ffat-lto-objects -fstack-protector-strong -Wformat -Werror=format-security -fPIC -Wdate-time -D_FORTIFY_SOURCE=2' \
        --with-ld-opt='-Wl,-Bsymbolic-functions -flto=auto -ffat-lto-objects -flto=auto -Wl,-z,relro -Wl,-z,now -fPIC' \
        --prefix=/usr                                    \
        --conf-path=/etc/nginx/nginx.conf                \
        --http-log-path=/var/log/nginx/access.log        \
        --error-log-path=/var/log/nginx/error.log        \
        --pid-path=/var/run/nginx.pid                    \
        --lock-path=/var/lock/nginx.lock                 \
        --http-client-body-temp-path=/var/lib/nginx/body \
        --http-fastcgi-temp-path=/var/lib/nginx/fastcgi  \
        --http-proxy-temp-path=/var/lib/nginx/proxy      \
        --http-scgi-temp-path=/var/lib/nginx/scgi        \
        --http-uwsgi-temp-path=/var/lib/nginx/uwsgi      \
        --with-threads                                   \
        --with-compat                                    \
        --with-debug                                     \
        --with-pcre-jit                                  \
        --with-http_ssl_module                           \
        --with-http_v2_module                            \
        --with-http_realip_module                        \
        --with-http_addition_module                      \
        --with-http_xslt_module                          \
        --with-http_image_filter_module                  \
        --with-http_geoip_module                         \
        --with-http_sub_module                           \
        --with-http_dav_module                           \
        --with-http_flv_module                           \
        --with-http_mp4_module                           \
        --with-http_gunzip_module                        \
        --with-http_gzip_static_module                   \
        --with-http_auth_request_module                  \
        --with-http_random_index_module                  \
        --with-http_secure_link_module                   \
        --with-http_degradation_module                   \
        --with-http_slice_module                         \
        --with-http_stub_status_module                   \
        --with-http_perl_module                          \
        --with-stream                                    \
        --with-stream_ssl_module                         \
        --with-stream_realip_module                      \
        --with-stream_geoip_module                       \
        --with-stream_ssl_preread_module                 \
        --add-module=../ngx_http_geoip2_module-${NGX_GEOIP2}        \
        --add-module=../ngx_http_proxy_connect_module-${NGX_CONNECT}\
        && \
    make && \
    sed -e 's%^DESTDIR\ .*$%DESTDIR ?=%' \
        -e 's%/usr/local/%/usr/%g' \
        -i objs/src/http/modules/perl/Makefile && \
    DESTDIR=/rootfs make install && \
    rm -rf /rootfs/var && \
    du -h -a /rootfs | tee /rootfs/installed-files

FROM ${BASEIMAGE}

# labels
LABEL maintainer="mtdcy.chen@gmail.com"

# always apply MIRROR
ARG MIRROR
RUN test -n "${MIRROR}" && { \
        sed -e "s|archive.ubuntu.com|${MIRROR}|g" \
            -e "s|security.ubuntu.com|${MIRROR}|g" \
            -i /etc/apt/sources.list.d/ubuntu.sources || true; \
        sed -e "s|dl-cdn.alpinelinux.org|${MIRROR}|g" \
            -i /etc/apk/repositories || true; \
    }

# install dependencies
RUN which apt-get && { \
        apt-get update && \
        apt-get install -y \
            libpcre3 \
            libxslt1.1 \
            libgd3 \
            libgeoip1t64 \
            perl \
            openssl \
            nginx-full \
            cron \
            logrotate \
            && \
        apt-get autoremove && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/*; \
    } || { \
        apk update && \
        apk add --no-cache \
            nginx \
            cron \
            logrotate \
            ; \
    }

# prepare rootfs
RUN \
    cp -r /etc/nginx /etc/nginx.default && \
    rm -rf /etc/cron.*

COPY --from=builder /rootfs/ /
COPY etc/ /etc/

# best practice: mount volume on /var/log
RUN ln -sfv /dev/stdout /var/log/nginx/access.log
RUN ln -sfv /dev/stderr /var/log/nginx/error.log

EXPOSE  80 443

ADD --chmod=0755 entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
