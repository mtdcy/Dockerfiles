# Custom docker images

## Quick Start

### Pull from registry

```shell
docker pull ghcr.io/mtdcy/baseimage:ubuntu-latest

docker pull ghcr.io/mtdcy/nginx:latest
```

### Build locally

```shell
make baseimage/Dockerfile

make nginx/Dockerfile
```
