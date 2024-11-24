# nginx @ alpine

## Addons/Features

- [nginx](http://nginx.org/download) @ 1.24.0
- [ngx_http_geoip2_module](https://github.com/leev/ngx_http_geoip2_module) @ HEAD
- [ngx_http_proxy_connect_module](https://github.com/chobits/ngx_http_proxy_connect_module) @ HEAD
- default [nginx.conf](nginx.conf)
- auto load '/app/*.nginx'
- `ln -sfv /dev/stdout /var/log/nginx/access.log`
- `ln -sfv /dev/stderr /var/log/nginx/error.log`
