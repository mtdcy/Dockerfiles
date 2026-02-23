all: build

build: 
	@docker build -t mtdcy/omnicache .

run: 
	@docker run -it --rm --name omnicache -p 8142:3142 mtdcy/omnicache bash
