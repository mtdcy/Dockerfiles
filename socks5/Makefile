
NAME 	= mtdcy/socks5
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
