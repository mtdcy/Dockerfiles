# OmniCache

## Ubuntu

```shell
sed -i 's%http://.*/%http://mirrors.mtdcy.top/%g' /etc/apt/sources.list
```

## pypi

```shell
pip3 config set global.index-url https://mirrors.mtdcy.top/pypi/simple
```

## npm

```shell
npm config set registry https://mirrors.mtdcy.top/npmjs
```

## Homebrew

```shell
# add lines to .zshrc or .bashrc
export HOMEBREW_BOTTLE_DOMAIN=http://mirrors.mtdcy.top/homebrew-bottles
export HOMEBREW_API_DOMAIN=http://mirrors.mtdcy.top/homebrew-bottles/api

# set homebrew/core remote
git -C "$(brew --repo homebrew/core)" remote set-url origin http://mirrors.mtdcy.top/homebrew-core.git 
```
