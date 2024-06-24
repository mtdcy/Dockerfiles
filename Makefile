SUBDIRS := base distcc socks5 printer

all: $(SUBDIRS)
$(SUBDIRS):
	$(MAKE) -C $@

.PHONY: all $(SUBDIRS)

DANGLING := $(shell docker images --filter "dangling=true" -q --no-trunc)

clean:
	test -n "$(DANGLING)" && docker rmi $(DANGLING) || true
	docker buildx prune
