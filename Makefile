
MAKEFLAGS += --always-make

MIRROR ?= http://mirrors.mtdcy.top

DOCKER_PLATFORM ?= linux/amd64

BUILDX_ARGS += --build-arg MIRROR=$(MIRROR)
BUILDX_ARGS += --build-arg TZ=Asia/Shanghai

# e.g: make baseimage/Dockerfile.alpine
%:
	@if test -d $@; then                   \
		docker compose                     \
			--project-directory $@         \
			--progress plain               \
			build $(BUILDX_ARGS);          \
	else                                   \
		docker buildx build $(BUILDX_ARGS) \
			-t $(shell dirname $@):latest  \
			--platform $(DOCKER_PLATFORM)  \
			--progress plain               \
			-f $@                          \
			$(shell dirname $@);           \
	fi

.PHONY:

DANGLING := $(shell docker images --filter "dangling=true" -q --no-trunc)

clean:
	test -n "$(DANGLING)" && docker rmi $(DANGLING) || true
	docker buildx prune -f
