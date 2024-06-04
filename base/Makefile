
# alpine
ALPINE_VERSION_MAJOR = 3
ALPINE_VERSION_MINOR = 20
ALPINE_VERSION = $(ALPINE_VERSION_MAJOR).$(ALPINE_VERSION_MINOR)

# ubuntu
UBUNTU_VERSION = jammy
UBUNTU_VERSION_ALT = 22.04

# mirror
MIRROR ?= http://mirrors.mtdcy.top

all: alpine ubuntu

alpine:
	docker buildx build --pull                       \
		-f Dockerfile.alpine                         \
		-t mtdcy/alpine:latest                       \
		-t mtdcy/alpine:$(ALPINE_VERSION_MAJOR)      \
		-t mtdcy/alpine:$(ALPINE_VERSION)            \
		--build-arg ALPINE_VERSION=$(ALPINE_VERSION) \
		--build-arg MIRROR=$(MIRROR)                 \
		.

ubuntu:
	docker buildx build --pull                       \
		-f Dockerfile.ubuntu                         \
		-t mtdcy/ubuntu:latest                       \
		-t mtdcy/ubuntu:$(UBUNTU_VERSION)            \
		--build-arg UBUNTU_VERSION=$(UBUNTU_VERSION) \
		--build-arg MIRROR=$(MIRROR)                 \
		.

run-alpine:
	docker run -it --rm mtdcy/alpine bash

run-ubuntu:
	docker run -it --rm mtdcy/ubuntu bash
