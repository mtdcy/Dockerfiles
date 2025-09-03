.PHONY: all

all:
	docker compose build
	docker rm nginx --volumes --force || true
	docker compose up -d
