# Custom docker images

## Quick Start

```shell
# Local Registry: lcr.io
docker pull lcr.io/mtdcy/baseimage:ubuntu-24.04
docker pull lcr.io/mtdcy/baseimage:alpine-3
docker pull lcr.io/mtdcy/nginx:latest

# Github Registry: ghcr.io
docker pull ghcr.io/mtdcy/baseimage:ubuntu-24.04
docker pull ghcr.io/mtdcy/baseimage:alpine-3
docker pull ghcr.io/mtdcy/nginx:latest
```

## Build

```shell
# baseimage
make ubuntu-latest
make alpine-latest

# normal images
make nginx/Dockerfile BASEIMAGE=baseimage:ubuntu-latest # use local built baseimage
make nginx/Dockerfile BASEIMAGE=lcr.io/mtdcy/baseimage:ubuntu-24.04 # pull baseimage from lcr.io
```

## Image List

- baseimage:
  - ubuntu-24.04
  - ubuntu-22.04
  - alpine-3
  - wine-latest
- nginx:latest
- ip2route:latest
- ...
