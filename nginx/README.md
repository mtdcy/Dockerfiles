# nginx

## Quick Start

```shell
docker pull ghcr.io/mtdcy/nginx:latest

docker run -it -d --name nginx \
         -p 80:80 \
         -p 8080:8080 \
         -p 7890:7890 \
         ghcr.io/mtdcy/nginx:latest
```

Access nginx ui with http://<your_ip>:8080.

Access nginx statistics with http://<your_ip>/report.html

### Ports

- 80/443    - http/https service port
- 8080      - nginx ui mgmt port
- 7890      - goaccess statistics port (WebSocket)

### Volumes

- /etc/nginx    - nginx config files
- /var/www      - sites contents
- /var/log      - log files

### Resources

- default [nginx.conf](rootfs/etc/nginx/nginx.conf).
- example [compose.yml](compose.yml)

## Addons/Features

- [nginx](http://nginx.org/download) @ latest
- [ngx_http_geoip2_module](https://github.com/leev/ngx_http_geoip2_module) @ latest
- [ngx_http_proxy_connect_module](https://github.com/chobits/ngx_http_proxy_connect_module) @ latest
- [ngx-fancyindex](https://github.com/aperezdc/ngx-fancyindex) @ latest

## Plugins

- [nginx-ui](https://github.com/0xJacky/nginx-ui)
- [goaccess](https://github.com/allinurl/goaccess)

## Build

- [Dockerfile](Dockerfile) - build nginx from sources
- [Dockerfile.lite](Dockerfile.lite) - use prebuilt static nginx

```shell
# always run inside top directory

make nginx/Dockerfile BASEIMAGE=lcr.io/mtdcy/baseimage:ubuntu-24.04

make nginx/Dockerfile BASEIMAGE=lcr.io/mtdcy/baseimage:alpine-3

make nginx/Dockerfile.lite BASEIMAGE=lcr.io/mtdcy/baseimage:alpine-3
```
