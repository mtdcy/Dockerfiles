.PHONY: all

all:
	docker compose build
	docker compose up -d

basic:
	docker compose -f basic.yaml build
	docker compose -f basic.yaml up -d

server:
	docker compose -f server.yaml build
	docker compose -f server.yaml up -d
