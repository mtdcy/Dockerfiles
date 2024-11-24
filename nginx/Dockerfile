# syntax=docker/dockerfile:1

FROM    mtdcy/alpine:latest

LABEL   maintainer="mtdcy.chen@gmail.com"

ARG NGX_VERSION=1.24.0
ARG NGX_CONNECT=0.0.5
ARG NGX_GEOIP2=3.4

## add user ##
# uid:33 is not available so choose 1000 instead
RUN apk add --no-cache shadow && useradd www-data -u 1000 -g 0 -M -s /sbin/nologin

ADD https://github.com/leev/ngx_http_geoip2_module/archive/${NGX_GEOIP2}.tar.gz \
    https://github.com/chobits/ngx_http_proxy_connect_module/archive/v${NGX_CONNECT}.tar.gz \
    http://nginx.org/download/nginx-${NGX_VERSION}.tar.gz \
    /tmp/build/

## build nginx ##
RUN apk add --no-cache build-base \
    && apk add --no-cache openssl pcre zlib libmaxminddb libxslt gd geoip perl \
    && apk add --no-cache openssl-dev pcre-dev zlib-dev libmaxminddb-dev libxslt-dev gd-dev geoip-dev perl-dev \
    && cd /tmp/build \
    && find . -name "*.tar.gz" -exec tar -xvf {} \; \
    && ls -l \
    && cd nginx-${NGX_VERSION}/ \
    && { \
        [ ${NGX_VERSION} = "1.24.0" ] && \
            patch -s -p1 < ../ngx_http_proxy_connect_module-${NGX_CONNECT}/patch/proxy_connect_rewrite_102101.patch; \
    } \
    && ./configure \
    --with-cc-opt='-g -O2 -flto=auto -ffat-lto-objects -flto=auto -ffat-lto-objects -fstack-protector-strong -Wformat -Werror=format-security -fPIC -Wdate-time -D_FORTIFY_SOURCE=2' \
    --with-ld-opt='-Wl,-Bsymbolic-functions -flto=auto -ffat-lto-objects -flto=auto -Wl,-z,relro -Wl,-z,now -fPIC' \
    --prefix=/usr                                    \
    --conf-path=/app/nginx/nginx.conf                \
    --http-log-path=/var/log/nginx/access.log        \
    --error-log-path=/var/log/nginx/error.log        \
    --pid-path=/run/nginx.pid                        \
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
    --add-module=../ngx_http_geoip2_module-${NGX_GEOIP2} \
    --add-module=../ngx_http_proxy_connect_module-${NGX_CONNECT} \
    && make -j4 && make install \
    && apk del build-base \*-dev \
    && cd / && rm -rf /tmp/build

ADD nginx.conf /app/nginx/nginx.conf

# prepare
RUN mkdir -pv /app /var/lib/nginx /var/log/nginx \
    && ln -sfv /dev/stdout /var/log/nginx/access.log \
    && ln -sfv /dev/stderr /var/log/nginx/error.log

# data volume: as nginx.conf specifies user, a sperate data volume
# is needed so that permissions can be set outside containers
VOLUME  ["/data"]
# exposed ports
EXPOSE  80 443

ADD entrypoint.sh /entrypoint.sh
RUN chmod 0755 /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
