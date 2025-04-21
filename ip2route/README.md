# ip2route

## Quick Start

1. Stop systemd-resolved

```shell
sudo systemctl disable systemd-resolved.service
```

2. Start a docker container

```shell
docker pull ghcr.io/mtdcy/ip2route:latest

#1. host mode
docker run -d                                    \
         --name ip2route                         \
         --network=host                          \
         --cap-add NET_ADMIN                     \
         --device /dev/net/tun                   \
         -e MODE=route                           \
         -e REMOTE_HOST=mtdcy@ecs.mtdcy.top:6015 \
         -v .:/config                            \
         -v ~/.ssh:/config/ssh                   \
         lcr.io/mtdcy/ip2route:latest
```

example [compose.yaml](compose.yaml).

3. Replace host dns server

```shell
sudo unlink /etc/resolv.conf

# use local host as dns server
cat <<EOF | sudo tee /etc/resolv.conf
nameserver $(ip route get 1.1.1.1 | grep -oP 'src \K\S+')
search local
EOF
```

**Do not use 127.0.0.1 as dns server**

4. Setup traffic rules

```shell
sudo iptables -I FORWARD -i br0 -o br0 -j ACCEPT
sudo iptables -I POSTROUTING -o br0 ! -m addrtype --src-type LOCAL -j MASQUERADE
```

## Q&A

### `Kernel module xt_set is not loaded in.`

  `xt_set` is needed by ipset.
