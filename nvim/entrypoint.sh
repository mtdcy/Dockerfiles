#!/bin/bash

[ -f "$HOME/.local/share/nvim/rplugin.vim" ] || nvim -c 'UpdateRemotePlugins' +quit

exec "$@"
