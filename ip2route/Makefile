.PHONY: all

all:
	docker compose build
	docker compose up -d

basic:
	sudo rm -rf basic0/*
	docker compose -f basic.yaml build
	docker compose -f basic.yaml up -d

serve:
	sudo rm -rf serve0/* 
	docker compose -f serve.yaml build
	docker compose -f serve.yaml up -d
