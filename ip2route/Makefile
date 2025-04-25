.PHONY: all

MAKEFLAGS += --always-make

all:
	docker stop ip2route || true
	docker rm -f ip2route || true
	docker compose build
	docker compose up -d
	docker logs -f ip2route

basic:
	docker stop ip2route || true
	docker rm -f ip2route || true
	docker compose -f basic.yaml build
	docker compose -f basic.yaml up -d
	docker logs -f ip2route

serve:
	docker stop ip2route || true
	docker rm -f ip2route || true
	docker compose -f serve.yaml build
	docker compose -f serve.yaml up -d
	docker logs -f ip2route

n2n:
	docker stop ip2route || true
	docker rm -f ip2route || true
	docker compose -f n2n.yaml build
	docker compose -f n2n.yaml up -d
	docker logs -f ip2route
