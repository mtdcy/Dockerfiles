
# official ubuntu
BASEIMAGE ?= ubuntu:24.04
# linuxserver baseimage: ubuntu + s6
#BASEIMAGE ?= lscr.io/linuxserver/baseimage-ubuntu:nobble

MIRROR ?= mirrors.mtdcy.top

MAKEFLAGS += --always-make

baseimage: 
	docker buildx build --pull          		\
		-t mtdcy/$@:latest           			\
		-t mcr.io/mtdcy/$@:latest       		\
		--build-arg BASEIMAGE=$(BASEIMAGE) 		\
		--build-arg MIRROR=$(MIRROR)    		\
		--build-arg TZ=Asia/Shanghai 			\
		$@

nginx-ui:
	docker buildx build 							\
		-t mtdcy/$@:latest           				\
		-t mcr.io/mtdcy/$@:latest      				\
		--build-arg BASEIMAGE=mtdcy/nginx:latest 	\
		--build-arg MIRROR=$(MIRROR)    			\
		--build-arg TZ=Asia/Shanghai 				\
		$@

%:
	docker buildx build 							\
		-t mtdcy/$@:latest           				\
		-t mcr.io/mtdcy/$@:latest      				\
		--build-arg BASEIMAGE=mtdcy/baseimage:latest\
		--build-arg MIRROR=$(MIRROR)    			\
		--build-arg TZ=Asia/Shanghai 				\
		$@

.PHONY: all

DANGLING := $(shell docker images --filter "dangling=true" -q --no-trunc)

clean:
	test -n "$(DANGLING)" && docker rmi $(DANGLING) || true
	docker buildx prune -f
