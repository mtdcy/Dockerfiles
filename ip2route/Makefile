.PHONY: all

MAKEFLAGS += --always-make

all:
	docker compose build
	docker compose up -d
	docker logs -f ip2route

basic:
	docker compose -f basic.yaml build
	docker compose -f basic.yaml up -d
	docker logs -f ip2route

serve:
	docker compose -f serve.yaml build
	docker compose -f serve.yaml up -d
	docker logs -f ip2route

n2n:
	docker compose -f n2n.yaml build
	docker compose -f n2n.yaml up -d
	docker logs -f ip2route
