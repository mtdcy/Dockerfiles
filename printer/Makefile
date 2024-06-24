

all: p910nd

cupsd:
	docker buildx build        \
		-f Dockerfile.cupsd    \
		-t mtdcy/cupsd:latest  \
		.

p910nd:
	docker buildx build        \
		-f Dockerfile.p910nd   \
		-t mtdcy/p910nd:latest \
		.

run:
	docker run -it --rm        \
		--device /dev/bus/usb  \
		mtdcy/printer bash
