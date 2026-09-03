all: Dockerfile Dockerfile.cygwin64 Dockerfile.mingw64

# common + musl-gcc + ubuntu
PARTS := \
	parts/Dockerfile.stage-1-common \
	parts/Dockerfile.stage-1-musl-gcc \
	parts/Dockerfile.final-common \
	parts/Dockerfile.final-ubuntu \

Dockerfile: $(PARTS)
	cat $^ > $@

CYGWIN64_PARTS := \
	parts/Dockerfile.stage-1-common \
	parts/Dockerfile.stage-1-cygwin64-gcc \
	parts/Dockerfile.final-common \
	parts/Dockerfile.final-cygwin64-gcc \
	parts/Dockerfile.final-wine \

Dockerfile.cygwin64: $(CYGWIN64_PARTS)
	cat $^ > $@

MINGW64_PARTS := \
	parts/Dockerfile.stage-1-common \
	parts/Dockerfile.stage-1-mingw64-llvm \
	parts/Dockerfile.final-common \
	parts/Dockerfile.final-mingw64-llvm \
	parts/Dockerfile.final-wine \

Dockerfile.mingw64: $(MINGW64_PARTS)
	cat $^ > $@
