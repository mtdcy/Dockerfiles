SUBDIRS := base distcc

all: $(SUBDIRS)
$(SUBDIRS):
	$(MAKE) -C $@

.PHONY: all $(SUBDIRS)

DANGLING := $(shell docker images --filter "dangling=true" -q --no-trunc)

clean:
	@docker rmi $(DANGLING)
	@docker buildx prune
