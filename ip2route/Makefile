.PHONY: all

MAKEFLAGS += --always-make

all:
	docker rm -f ip2route
	docker compose build
	docker compose up -d
	docker logs -f ip2route

basic:
	docker rm -f ip2route
	docker compose -f basic.yaml build
	docker compose -f basic.yaml up -d
	docker logs -f ip2route

serve:
	docker rm -f ip2route
	docker compose -f serve.yaml build
	docker compose -f serve.yaml up -d
	docker logs -f ip2route

n2n:
	docker rm -f ip2route
	docker compose -f n2n.yaml build
	docker compose -f n2n.yaml up -d
	docker logs -f ip2route
