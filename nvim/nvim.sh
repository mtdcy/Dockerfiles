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

# user
[ "$(id -u)" -eq 0 ] || opts+=( -e "PUID=$(id -u)" -e "PGID=$(id -g)" )
# ncopyc.sh
[ -z "$SSH_CLIENT" ] || opts+=( -e "SSH_CLIENT=$SSH_CLIENT" )
# HOME
opts+=( -v "$HOME:$HOME" )
# PWD
[[ "$PWD" =~ ^$HOME ]] || opts+=( -v "$PWD:$PWD" )
opts+=( -w "$PWD" )

for v in "$@"; do
    case "$v" in
        -*) ;;
        *)
            # files must exists before mounting
            test -e "$v" || touch "$v"
            # get full path
            v="$(realpath -s "$v")"
            # mount if not in HOME or PWD
            [[ "$v" =~ ^$HOME ]] || [[ "$v" =~ ^$PWD ]] || opts+=( -v "$v:$v" )
            ;;
    esac
done

docker run -it --rm "${opts[@]}" "$IMAGE" nvim "$@"
