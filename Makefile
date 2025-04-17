
MAKEFLAGS += --always-make

MIRROR ?= http://mirrors.mtdcy.top

BUILDX_ARGS += --build-arg MIRROR=$(MIRROR)
BUILDX_ARGS += --build-arg TZ=Asia/Shanghai

# e.g: make baseimage/Dockerfile.alpine
%:
	docker buildx build $(BUILDX_ARGS) 	\
		-t $(shell dirname $@):latest  	\
		--progress plain 				\
		-f $@ 							\
		$(shell dirname $@)

.PHONY: all

DANGLING := $(shell docker images --filter "dangling=true" -q --no-trunc)

clean:
	test -n "$(DANGLING)" && docker rmi $(DANGLING) || true
	docker buildx prune -f
