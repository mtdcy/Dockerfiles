# syntax=docker/dockerfile:1
FROM baseimage:latest AS builder

ARG NGX_VER=1.27.5
ARG NGX_CONNECT_VER=0.0.7
ARG NGX_GEOIP2_VER=3.4
ARG NGX_FANCYINDEX_VER=0.5.2

ADD https://github.com/leev/ngx_http_geoip2_module/archive/$NGX_GEOIP2_VER.tar.gz \
    https://github.com/chobits/ngx_http_proxy_connect_module/archive/v$NGX_CONNECT_VER.tar.gz \
    https://github.com/aperezdc/ngx-fancyindex/archive/v$NGX_FANCYINDEX_VER.tar.gz \
    http://nginx.org/download/nginx-$NGX_VER.tar.gz \
    /tmp/build/

SHELL ["bash", "-c"]
RUN <<-EOS
    set -ex
    echo "**** prepare build tools ****"

    if which apt-get; then
        apt-get update
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
            libperl-dev
    else
        apk update
        apk add --no-cache \
            build-base \
            openssl-dev \
            pcre-dev \
            zlib-dev \
            libmaxminddb-dev \
            libxslt-dev \
            gd-dev \
            geoip-dev \
            perl-dev
    fi
EOS

SHELL ["bash", "-c"]
RUN <<-EOS
    echo "**** build nginx ****"

    cd /tmp/build
    find . -name "*.tar.gz" -exec tar -xf {} \;
    cd nginx-$NGX_VER
    case "$NGX_VER" in
        1.24.*|1.25.*|1.26.*|1.27.*)
            patch -p1 < ../ngx_http_proxy_connect_module-$NGX_CONNECT_VER/patch/proxy_connect_rewrite_102101.patch
            ;;
    esac

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
        --add-module=../ngx_http_geoip2_module-$NGX_GEOIP2_VER          \
        --add-module=../ngx_http_proxy_connect_module-$NGX_CONNECT_VER  \
        --add-module=../ngx-fancyindex-$NGX_FANCYINDEX_VER
    make
    sed -e 's%^DESTDIR\ .*$%DESTDIR ?=%' \
        -e 's%/usr/local/%/usr/%g' \
        -i objs/src/http/modules/perl/Makefile
    DESTDIR=/rootfs make install
    rm -rf /rootfs/var
    du -h -a /rootfs | tee /rootfs/installed-files
EOS

FROM baseimage:latest

# labels
LABEL maintainer="mtdcy.chen@gmail.com"

# install dependencies
SHELL ["bash", "-c"]
RUN <<-EOS
    set -ex
    echo "**** install nginx runtimes ****"

    if which apt-get; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y \
            libpcre3 libxslt1.1 libgd3 libgeoip1t64 \
            perl openssl nginx-full \
            cron logrotate
        apt-get autoremove
        apt-get clean
        rm -rf /var/lib/apt/lists/*
    else
        apk update
        apk add --no-cache nginx cron logrotate
    fi
EOS

# prepare rootfs
COPY --from=builder /rootfs/ /
COPY rootfs/ /

# prepare plugins
ARG NGX_UI_VER=2.0.0-rc.5

ARG TARGETPLATFORM

SHELL ["bash", "-c"]
RUN <<-EOS
    set -ex -o pipefail
    echo "**** prepare nginx-ui ****"

    TARGET="linux-64"
    case "$TARGETPLATFORM" in
        linux/arm64)    TARGET=linux-arm64-v8a ;;
    esac

    curl -sL https://github.com/0xJacky/nginx-ui/releases/download/v$NGX_UI_VER/nginx-ui-${TARGET,,}.tar.gz | tar -C /usr/bin/ -xz nginx-ui

    echo "**** finish ****"

    ldconfig
    nginx -V
    nginx-ui -version

    mv /etc/nginx /etc/nginx.default

    ln -sfv /dev/stdout /var/log/nginx/access.log
    ln -sfv /dev/stderr /var/log/nginx/error.log

    # no default crontab for logrotate
    rm -rf /etc/cron.*
EOS

# 8080 for mgmt
EXPOSE  80 443 8080

VOLUME /etc/nginx

ENTRYPOINT ["/entrypoint.sh"]
