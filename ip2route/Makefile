.PHONY: all

all:
	docker compose build
	docker compose up -d

server:
	docker compose -f server.yaml build
	docker compose -f server.yaml up
