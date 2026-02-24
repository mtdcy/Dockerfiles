
MAKEFLAGS += --always-make

MIRROR ?= https://mirrors.mtdcy.top

ifeq ($(shell uname -m),arm64)
DOCKER_PLATFORM ?= linux/arm64
else
DOCKER_PLATFORM ?= linux/amd64
endif

#BUILDX_ARGS += --progress=plain
BUILDX_ARGS += --build-arg MIRROR=$(MIRROR)
BUILDX_ARGS += --build-arg TZ=Asia/Shanghai
BUILDX_ARGS += --build-arg CACHEBUST=$(shell date +%s)

ubuntu-latest:
	@docker buildx build $(BUILDX_ARGS)                                  \
		--platform $(DOCKER_PLATFORM)                                    \
		--build-context ubuntu:latest=docker-image://ubuntu:24.04        \
		-t baseimage:$@ -f baseimage/Dockerfile baseimage

alpine-latest:
	@docker buildx build $(BUILDX_ARGS)                                  \
		--platform $(DOCKER_PLATFORM)                                    \
		--build-context ubuntu:latest=docker-image://alpine:3            \
		-t baseimage:$@ -f baseimage/Dockerfile baseimage

BASEIMAGE ?= baseimage:ubuntu-latest

# e.g: make baseimage/Dockerfile.alpine
%:
	if test -d $@; then                                                  \
		docker compose --project-directory $@                            \
			build $(BUILDX_ARGS);                                        \
	else                                                                 \
		docker buildx build $(BUILDX_ARGS)                               \
			--platform $(DOCKER_PLATFORM)                                \
			--build-context baseimage:latest=docker-image://$(BASEIMAGE) \
			-t $(shell dirname $@):latest                                \
			-f $@ $(shell dirname $@);                                   \
	fi

.PHONY:

DANGLING := $(shell docker images --filter "dangling=true" -q --no-trunc)

clean:
	test -n "$(DANGLING)" && docker rmi $(DANGLING) || true
	docker buildx prune -f
