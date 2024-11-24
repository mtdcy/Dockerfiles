all: build

build: 
	@docker build -t mtdcy/nginx:latest -t mtdcy/nginx:1.24.0 .

build-with-proxy: 
	@docker build -t mtdcy/nginx --build-arg HTTP_PROXY='http://mirrors.mtdcy.top:3128' .

run: 
	@docker run -it --rm --name nginx -p 8080:80 mtdcy/nginx sh
