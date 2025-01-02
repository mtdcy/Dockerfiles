# builder/buildbot images

## Available Images

- lcr.io/mtdcy/builder:ubuntu-latest
- lcr.io/mtdcy/builder:alpine-latest
- lcr.io/mtdcy/builder:mingw64-latest
- lcr.io/mtdcy/builder:clang64-latest
- lcr.io/mtdcy/builder:ucrt64-latest

## Quick Start

```shell
docker pull lcr.io/mtdcy/builder:ubuntu-latest
docker run --rm -it -e PUID=1000 -e PGID=1000 lcr.io/mtdcy/builder:ubuntu-latest
```
