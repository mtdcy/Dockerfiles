
REGISTRY ?= mcr.io

# official ubuntu
BASEIMAGE ?= ubuntu:24.04

MIRROR ?= mirrors.mtdcy.top

MAKEFLAGS += --always-make

%:
	docker buildx build 					\
		-t mtdcy/$@:latest           		\
		-t $(REGISTRY)/mtdcy/$@:latest      \
		--build-arg BASEIMAGE=${BASEIMAGE} 	\
		--build-arg MIRROR=$(MIRROR)    	\
		--build-arg TZ=Asia/Shanghai 		\
		$@

.PHONY: all

DANGLING := $(shell docker images --filter "dangling=true" -q --no-trunc)

clean:
	test -n "$(DANGLING)" && docker rmi $(DANGLING) || true
	docker buildx prune -f
