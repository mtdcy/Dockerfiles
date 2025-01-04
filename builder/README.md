# builder/buildbot images

## Available Images

### Linux Images

- lcr.io/mtdcy/builder:ubuntu-latest
- lcr.io/mtdcy/builder:alpine-latest
- lcr.io/mtdcy/builder:mingw64-latest
- lcr.io/mtdcy/builder:clang64-latest
- lcr.io/mtdcy/builder:ucrt64-latest

### Windows Images

-

## Quick Start

```shell
docker pull lcr.io/mtdcy/builder:ubuntu-latest
docker run --rm -it -e PUID=1000 -e PGID=1000 lcr.io/mtdcy/builder:ubuntu-latest
```

## Notes

- always run as buildbot, PUID|PGID are accepted.
- use `docker run ... root` to require root permission.

## BUSS

### MSYS2

- Ctrl-C doesn't work
- 'ln: failed to create symbolic link '/etc/mtab': Permission denied'
