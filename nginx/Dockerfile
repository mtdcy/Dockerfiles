# syntax=docker/dockerfile:1
FROM baseimage:latest AS builder

ARG NGX_VER=1.27.5
ARG NGX_GEOIP2_VER=3.4
ARG NGX_FANCYINDEX_VER=0.5.2

ADD https://github.com/leev/ngx_http_geoip2_module/archive/$NGX_GEOIP2_VER.tar.gz \
    https://github.com/aperezdc/ngx-fancyindex/archive/v$NGX_FANCYINDEX_VER.tar.gz \
    http://nginx.org/download/nginx-$NGX_VER.tar.gz \
    /tmp/build/

# no cache for this stage
ARG CACHEBUST=1

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

        echo "**** prepare goaccess ****"
        apt-get install -y goaccess

        apt-get autoremove
        apt-get clean
        rm -rf /var/lib/apt/lists/*
    else
        apk update
        apk add --no-cache nginx cron logrotate goaccess
    fi

    # goaccess: share the same conf dir with nginx
    mv /etc/goaccess/* /etc/nginx/
    rm -rf /etc/goaccess

    # no default crontab for logrotate
    rm -rf /etc/cron.*
EOS

ARG NGX_UI_VER=2.1.17
ARG TARGETPLATFORM
RUN <<-EOS
    set -ex
    echo "**** prepare nginx-ui ****"

    TARGET="linux-64"
    case "$TARGETPLATFORM" in
        linux/arm64)    TARGET=linux-arm64-v8a ;;
    esac

    curl -sL https://github.com/0xJacky/nginx-ui/releases/download/v$NGX_UI_VER/nginx-ui-${TARGET,,}.tar.gz | tar -C /usr/bin/ -xz nginx-ui
EOS

# prepare rootfs
COPY --from=builder /rootfs/ /
COPY rootfs/ /

SHELL ["bash", "-c"]
RUN <<-EOS
    set -ex -o pipefail
    echo "**** finish ****"

    ldconfig
    nginx -V
    nginx-ui -version

    mv /etc/nginx /etc/nginx.default

    rm -fv /var/www/html/*
    cp -fv /etc/nginx.default/index.html /var/www/html/
EOS

# 8080 for mgmt, 7890 for goaccess
EXPOSE  80 443 8080 7890

VOLUME /etc/nginx
VOLUME /var/www/html
VOLUME /var/log

ENTRYPOINT ["/entrypoint.sh"]
