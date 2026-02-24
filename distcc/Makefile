NAME 	= mtdcy/distcc
VERSION = 1.0

all: alpine ubuntu

alpine:
	docker buildx build              \
		-f Dockerfile.alpine         \
		-t $(NAME)-alpine:latest     \
		-t $(NAME)-alpine:$(VERSION) \
		.

ubuntu:
	docker buildx build              \
		-f Dockerfile.ubuntu         \
		-t $(NAME)-ubuntu:latest     \
		-t $(NAME)-ubuntu:$(VERSION) \
		.

run-alpine:
	docker run -it --rm mtdcy/distcc-alpine bash

run-ubuntu:
	docker run -it --rm mtdcy/distcc-ubuntu bash

compose:
	docker compose up -d
