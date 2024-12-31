
# no default value
BASEIMAGE ?=

REGISTRY ?= lcr.io

MIRROR ?= mirrors.mtdcy.top

MAKEFLAGS += --always-make

BUILDX_ARGS += --build-arg MIRROR=$(MIRROR)
BUILDX_ARGS += --build-arg TZ=Asia/Shanghai

ifneq ($(BASEIMAGE),)
BUILDX_ARGS += --build-arg BASEIMAGE=$(BASEIMAGE)
endif

# e.g: make baseimage/Dockerfile.alpine
%:
	docker buildx build $(BUILDX_ARGS) 					\
		-t mtdcy/$(shell dirname $@):latest          	\
		-t $(REGISTRY)/mtdcy/$(shell dirname $@):latest \
		--output type=docker 							\
		-f $@ 											\
		$(shell dirname $@)

.PHONY: all

DANGLING := $(shell docker images --filter "dangling=true" -q --no-trunc)

clean:
	test -n "$(DANGLING)" && docker rmi $(DANGLING) || true
	docker buildx prune -f
