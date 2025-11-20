# =============================================================================
# Makefile for Custom Linux Distribution
# =============================================================================

.PHONY: all build clean test run extract help docker-build docker-run \
        docker-clean iso kernel initramfs boot-img qemu qemu-nographic

# Configuration
IMAGE_NAME := handbuilt-linux
DOCKER_TAG := latest
ISO_OUTPUT := output.iso
BOOT_IMG := boot.img
QEMU_MEMORY := 512M

# Colors for output
COLOR_RESET := \033[0m
COLOR_BOLD := \033[1m
COLOR_GREEN := \033[32m
COLOR_BLUE := \033[34m
COLOR_YELLOW := \033[33m

# Default target
all: help

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------
help:
	@echo "$(COLOR_BOLD)handbuilt-linux Build System$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BOLD)Available targets:$(COLOR_RESET)"
	@echo "  $(COLOR_GREEN)build$(COLOR_RESET)            - Build Docker image"
	@echo "  $(COLOR_GREEN)extract$(COLOR_RESET)          - Extract build artifacts from Docker"
	@echo "  $(COLOR_GREEN)iso$(COLOR_RESET)              - Extract ISO image only"
	@echo "  $(COLOR_GREEN)kernel$(COLOR_RESET)           - Extract kernel image only"
	@echo "  $(COLOR_GREEN)initramfs$(COLOR_RESET)        - Extract initramfs only"
	@echo "  $(COLOR_GREEN)boot-img$(COLOR_RESET)         - Create bootable disk image"
	@echo "  $(COLOR_GREEN)run$(COLOR_RESET)              - Run Docker container interactively"
	@echo "  $(COLOR_GREEN)test$(COLOR_RESET)             - Run tests"
	@echo "  $(COLOR_GREEN)qemu$(COLOR_RESET)             - Run ISO in QEMU"
	@echo "  $(COLOR_GREEN)qemu-nographic$(COLOR_RESET)   - Run ISO in QEMU (no graphics)"
	@echo "  $(COLOR_GREEN)clean$(COLOR_RESET)            - Remove build artifacts"
	@echo "  $(COLOR_GREEN)docker-clean$(COLOR_RESET)     - Remove Docker images and containers"
	@echo "  $(COLOR_GREEN)help$(COLOR_RESET)             - Show this help message"
	@echo ""
	@echo "$(COLOR_BOLD)Examples:$(COLOR_RESET)"
	@echo "  make build              # Build the Docker image"
	@echo "  make extract            # Extract all artifacts"
	@echo "  make qemu               # Test with QEMU"
	@echo "  make clean build        # Clean and rebuild"
	@echo ""

# -----------------------------------------------------------------------------
# Docker Build
# -----------------------------------------------------------------------------
build: docker-build

docker-build:
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)Building Docker image...$(COLOR_RESET)"
	docker build -t $(IMAGE_NAME):$(DOCKER_TAG) .
	@echo "$(COLOR_BOLD)$(COLOR_GREEN)✓ Docker image built successfully$(COLOR_RESET)"

# Build specific stages
docker-build-kernel:
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)Building kernel stage...$(COLOR_RESET)"
	docker build --target kernel-builder -t $(IMAGE_NAME):kernel .

docker-build-busybox:
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)Building BusyBox stage...$(COLOR_RESET)"
	docker build --target busybox-builder -t $(IMAGE_NAME):busybox .

docker-build-iso:
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)Building ISO stage...$(COLOR_RESET)"
	docker build --target iso-builder -t $(IMAGE_NAME):iso .

# -----------------------------------------------------------------------------
# Extract Artifacts
# -----------------------------------------------------------------------------
extract: iso kernel initramfs
	@echo "$(COLOR_BOLD)$(COLOR_GREEN)✓ All artifacts extracted$(COLOR_RESET)"

iso: build
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)Extracting ISO image...$(COLOR_RESET)"
	@docker run --rm $(IMAGE_NAME):$(DOCKER_TAG) cat /distro/output.iso > $(ISO_OUTPUT)
	@echo "$(COLOR_BOLD)$(COLOR_GREEN)✓ ISO extracted: $(ISO_OUTPUT)$(COLOR_RESET)"

kernel: build
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)Extracting kernel...$(COLOR_RESET)"
	@docker run --rm $(IMAGE_NAME):$(DOCKER_TAG) cat /distro/bzImage > bzImage
	@echo "$(COLOR_BOLD)$(COLOR_GREEN)✓ Kernel extracted: bzImage$(COLOR_RESET)"

initramfs: build
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)Extracting initramfs...$(COLOR_RESET)"
	@docker run --rm $(IMAGE_NAME):$(DOCKER_TAG) cat /distro/initramfs > initramfs
	@echo "$(COLOR_BOLD)$(COLOR_GREEN)✓ Initramfs extracted: initramfs$(COLOR_RESET)"

# -----------------------------------------------------------------------------
# Boot Image
# -----------------------------------------------------------------------------
boot-img: extract
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)Creating bootable disk image...$(COLOR_RESET)"
	@./build.sh
	@echo "$(COLOR_BOLD)$(COLOR_GREEN)✓ Boot image created: $(BOOT_IMG)$(COLOR_RESET)"

# -----------------------------------------------------------------------------
# Docker Run
# -----------------------------------------------------------------------------
run: docker-run

docker-run: build
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)Running Docker container...$(COLOR_RESET)"
	docker run --rm -it $(IMAGE_NAME):$(DOCKER_TAG)

# Run with mounted volume
docker-run-mount: build
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)Running Docker container with mounted volume...$(COLOR_RESET)"
	docker run --rm -it -v $(PWD)/output:/output $(IMAGE_NAME):$(DOCKER_TAG)

# -----------------------------------------------------------------------------
# Testing
# -----------------------------------------------------------------------------
test: build
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)Running tests...$(COLOR_RESET)"
	@if [ -f scripts/test.sh ]; then \
		./scripts/test.sh; \
	else \
		echo "$(COLOR_YELLOW)No test script found$(COLOR_RESET)"; \
	fi

# Test with QEMU
test-qemu: qemu-nographic

# -----------------------------------------------------------------------------
# QEMU
# -----------------------------------------------------------------------------
qemu: iso
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)Starting QEMU...$(COLOR_RESET)"
	@echo "$(COLOR_YELLOW)Press Ctrl+Alt+2 for QEMU console, Ctrl+Alt+1 to return$(COLOR_RESET)"
	qemu-system-x86_64 -cdrom $(ISO_OUTPUT) -m $(QEMU_MEMORY)

qemu-nographic: iso
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)Starting QEMU (no graphics)...$(COLOR_RESET)"
	@echo "$(COLOR_YELLOW)Press Ctrl+A then X to exit$(COLOR_RESET)"
	qemu-system-x86_64 -cdrom $(ISO_OUTPUT) -m $(QEMU_MEMORY) -nographic

qemu-kernel: kernel initramfs
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)Starting QEMU with kernel and initramfs...$(COLOR_RESET)"
	qemu-system-x86_64 \
		-kernel bzImage \
		-initrd initramfs \
		-append "console=ttyS0" \
		-m $(QEMU_MEMORY) \
		-nographic

qemu-boot-img: boot-img
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)Starting QEMU with boot image...$(COLOR_RESET)"
	qemu-system-x86_64 $(BOOT_IMG) -m $(QEMU_MEMORY)

# QEMU with network
qemu-network: iso
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)Starting QEMU with network...$(COLOR_RESET)"
	qemu-system-x86_64 \
		-cdrom $(ISO_OUTPUT) \
		-m $(QEMU_MEMORY) \
		-netdev user,id=net0 \
		-device e1000,netdev=net0

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------
clean:
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)Cleaning build artifacts...$(COLOR_RESET)"
	@rm -f $(ISO_OUTPUT) $(BOOT_IMG) bzImage initramfs initramfs.cpio.gz
	@rm -rf mnt/ myiso/ initramfs/ build/ output/
	@echo "$(COLOR_BOLD)$(COLOR_GREEN)✓ Cleaned$(COLOR_RESET)"

docker-clean:
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)Cleaning Docker images...$(COLOR_RESET)"
	@docker rmi $(IMAGE_NAME):$(DOCKER_TAG) 2>/dev/null || true
	@docker rmi $(IMAGE_NAME):kernel 2>/dev/null || true
	@docker rmi $(IMAGE_NAME):busybox 2>/dev/null || true
	@docker rmi $(IMAGE_NAME):iso 2>/dev/null || true
	@echo "$(COLOR_BOLD)$(COLOR_GREEN)✓ Docker images removed$(COLOR_RESET)"

clean-all: clean docker-clean
	@echo "$(COLOR_BOLD)$(COLOR_GREEN)✓ Full cleanup complete$(COLOR_RESET)"

# -----------------------------------------------------------------------------
# Development
# -----------------------------------------------------------------------------
shell: docker-run

# Enter build container for debugging
debug: build
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)Starting debug shell...$(COLOR_RESET)"
	docker run --rm -it --entrypoint /bin/bash $(IMAGE_NAME):$(DOCKER_TAG)

# Show build logs
logs:
	@docker logs $(shell docker ps -lq)

# Show Docker image size
size: build
	@echo "$(COLOR_BOLD)Image sizes:$(COLOR_RESET)"
	@docker images $(IMAGE_NAME):$(DOCKER_TAG) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
menuconfig-kernel:
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)Configuring kernel...$(COLOR_RESET)"
	docker run --rm -it -v $(PWD):/work $(IMAGE_NAME):$(DOCKER_TAG) bash -c \
		"cd /opt/mydistro/linux && make menuconfig && cp .config /work/linux.config"

menuconfig-busybox:
	@echo "$(COLOR_BOLD)$(COLOR_BLUE)Configuring BusyBox...$(COLOR_RESET)"
	docker run --rm -it -v $(PWD):/work $(IMAGE_NAME):$(DOCKER_TAG) bash -c \
		"cd /opt/mydistro/busybox && make menuconfig && cp .config /work/busybox.config"

# -----------------------------------------------------------------------------
# CI/CD
# -----------------------------------------------------------------------------
ci: clean build test
	@echo "$(COLOR_BOLD)$(COLOR_GREEN)✓ CI build complete$(COLOR_RESET)"

# Check for required tools
check-deps:
	@echo "$(COLOR_BOLD)Checking dependencies...$(COLOR_RESET)"
	@command -v docker >/dev/null 2>&1 || { echo "$(COLOR_RED)✗ docker not found$(COLOR_RESET)"; exit 1; }
	@command -v qemu-system-x86_64 >/dev/null 2>&1 || echo "$(COLOR_YELLOW)! qemu-system-x86_64 not found (optional)$(COLOR_RESET)"
	@echo "$(COLOR_BOLD)$(COLOR_GREEN)✓ All required dependencies found$(COLOR_RESET)"
