
NAME 	= mtdcy/dnsmasq
VERSION = 1.0

all: alpine

alpine:
	docker buildx build       \
		-f Dockerfile         \
		-t $(NAME):latest     \
		-t $(NAME):$(VERSION) \
		.

compose:
	docker compose up -d

# dhcp works easy with host network mode
test-dhcp:
	sudo nmap --script broadcast-dhcp-discover -e br0
