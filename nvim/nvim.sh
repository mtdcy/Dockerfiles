#!/bin/bash

IMAGE=nvim:latest

if [ "$*" = "--update" ] || [ -z "$(docker image ls "$IMAGE" -q)" ]; then
    if curl --fail -sIL http://lcr.io -o /dev/null; then
        IMAGE=lcr.io/mtdcy/nvim:latest
    else
        IMAGE=ghcr.io/mtdcy/nvim:latest
    fi
    docker pull "$IMAGE"
    docker tag "$IMAGE" nvim:latest
fi

[ "$*" = "--update" ] && exit 0

opts+=( --user "$(id -u):$(id -g)" -v /etc/passwd:/etc/passwd -v /etc/group:/etc/group )

opts+=( -v "$HOME:$HOME" )

opts+=( -w "$PWD" )

[[ "$PWD" =~ ^$HOME ]] || opts+=( -v "$PWD:$PWD" )

for x in "$@"; do
    case "$x" in
        -*) ;;
        *)
            test -f "$x" || touch "$x"
            x="$(realpath "$x")"
            [[ "$x" =~ "$HOME" ]] || [[ "$x" =~ "$PWD" ]] || opts+=( -v "$x:$x" )
            ;;
    esac
done

docker run -it --rm "${opts[@]}" "$IMAGE" nvim "$@"
