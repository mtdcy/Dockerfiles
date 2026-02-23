# ip2route

A ip routing container based on ssh tunnel, including basic|route|serve modes.

```
       | gw in route mode |            | host in serve mode |
 pc --- lan ------> wan ---> internet
            \             | ssh tunnel |
             \----> tun0 <--------------> tun0 --------> wan ---> internet
            ^
            |
         ip2route
```

## Features

- route based on ipset [files](data/dns.ip). (route mode only)
- socks5 proxy
- dns server

## Quick Start

1. Prepare sshd (serve mode)

```shell
if ! sudo sshd -T | grep -Fwi 'PermitTunnel' | grep -Fqi yes; then
  echo 'PermitTunnel yes' | sudo tee -a /etc/ssh/sshd_config
  sudo systemctl restart sshd
fi
```

2. Start a docker container

```shell
docker pull ghcr.io/mtdcy/ip2route:latest

# route mode
docker run -d                               \
         --name ip2route                    \
         --network=host                     \
         --cap-add NET_ADMIN                \
         --device /dev/net/tun              \
         -e MODE=route                      \
         -e REMOTE_HOST=user@example.org:22 \
         -e LOCAL_ADDR=10.0.0.10/24         \
         -e REMOTE_ADDR=10.0.0.1            \
         -v .:/config                       \
         -v ~/.ssh:/config/ssh              \
         ghcr.io/mtdcy/ip2route:latest

# basic mode (socks5 + dnsmasq)
docker run -d                               \
         --name ip2route                    \
         --network=bridge                   \
         -e MODE=basic                      \
         -e REMOTE_HOST=user@example.org:22 \
         -e DNSMASQ_SERVER=8.8.8.8          \
         -v .:/config                       \
         -v ~/.ssh:/config/ssh              \
         ghcr.io/mtdcy/ip2route:latest

# serve mode (sshd + dnsmasq)
docker run -d                               \
         --name ip2route                    \
         --network=host                     \
         --cap-add NET_ADMIN                \
         --device /dev/net/tun              \
         -e MODE=serve                      \
         -e LOCAL_ADDR=10.0.0.1/24          \
         -e DEVICE_COUNT=3                  \
         -e DNSMASQ_SERVER=8.8.8.8          \
         -v .:/config                       \
         ghcr.io/mtdcy/ip2route:latest
```

example [route](compose.yaml)|[basic](basic.yaml)|[serve](serve.yaml) files.

3. Replace host dns server

```shell
sudo systemctl disable systemd-resolved.service --now

sudo unlink /etc/resolv.conf

# use local host as dns server
cat <<EOF | sudo tee /etc/resolv.conf
nameserver $(ip route get 114.114.114.114 | grep -oP 'src \K\S+')
search local
EOF
```

**Do not use 127.0.0.1 as dns server**

## Q&A

### `Kernel module xt_set is not loaded in.`

  kernel mode `xt_set` is needed by ipset by ip2route.

### n2n edge/gateway cann't ping internal IPs

  `sudo sysctl -w net.ipv4.conf.n2n0.proxy_arp=1`

## Releases

- 1.0.8 update afw
- 1.0.7 update afw rules
- 1.0.6 add sysctl/afw/conntrack/iperf3
- 1.0.5 add net route support
- 1.0.4 add n2n tunnel
- 1.0.3 fix socks mode
- 1.0.2 bug fix
- 1.0.1 fix resolve issues after setting host dns server
- 1.0.0 first version
