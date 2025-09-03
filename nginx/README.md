# nginx

## Quick Start

```shell
docker pull ghcr.io/mtdcy/nginx:latest

docker run -it -d --name nginx \
         -p 80:80 \
         -p 8080:8080 \
         ghcr.io/mtdcy/nginx:latest
```

Access nginx ui with http://<your_ip>:8080.

Access nginx statistics with http://<your_ip>/report.html

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
