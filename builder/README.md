# builder/buildbot images

## Available Images

### Images

- lcr.io/mtdcy/builder:ubuntu-latest    (Linux targets)
- lcr.io/mtdcy/builder:mingw64-latest   (Windows targets)

## Quick Start

```shell
docker pull lcr.io/mtdcy/builder:ubuntu-latest
docker run --rm -it -e PUID=1000 -e PGID=1000 lcr.io/mtdcy/builder:ubuntu-latest
```

## Notes

- always run as buildbot, PUID|PGID are accepted.
- use `docker run ... root` to require root permission.

## BUGS
