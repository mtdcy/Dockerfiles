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

    [ "$*" = "--update" ] && exit 0
fi

# user
[ "$(id -u)" -eq 0 ] || {
    opts+=( -e "PUID=$(id -u)" -e "PGID=$(id -g)" )
    # .gitconfig
    opts+=( -v "$HOME/.gitconfig:/home/nvim/.gitconfig" )
}
# ncopyc.sh
[ -z "$SSH_CLIENT" ] || opts+=( -e "SSH_CLIENT=$SSH_CLIENT" )
# PWD
opts+=( -v "$PWD:$PWD" -w "$PWD" )

args=()
while [ $# -gt 0 ]; do
    v="$1"; shift
    args+=("$v")
    case "$v" in
        -c|-l|-s|-S|-u|-i)  args+=("$1"); shift ;;
        --server)           args+=("$1"); shift ;;
        --startuptime)      args+=("$1"); shift ;;
        --listen)           args+=("$1"); shift ;;
        -*|+*)  ;;
        *)
            # files must exists before mounting
            test -e "$v" || touch "$v"
            # get full path
            v="$(realpath -s "$v")"
            # mount if not in PWD
            [[ "$v" =~ ^$PWD ]] || opts+=( -v "$v:$v" )
            ;;
    esac
done

NVIM="nvim-$$"

docker run -it --rm --name=$NVIM -d "${opts[@]}" "$IMAGE" nvim "${args[@]}" >/dev/null

# Ctrl-z
while true; do
    docker attach "$NVIM" --sig-proxy=false --detach-keys='ctrl-z'
    docker ps | grep -Fwq "$NVIM" || exit 0
    kill -TSTP $$;
done
