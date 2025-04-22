.PHONY: all

all:
	docker compose build
	docker compose up -d

socks5:
	docker compose -f socks5.yaml build
	docker compose -f socks5.yaml up -d

server:
	docker compose -f server.yaml build
	docker compose -f server.yaml up
