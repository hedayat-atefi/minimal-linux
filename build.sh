#!/usr/bin/env bash

# =============================================================================
# Build Script for Custom Linux Distribution
# =============================================================================
# This script creates a bootable disk image with the custom Linux distro
#
# Usage:
#   ./build.sh [OPTIONS]
#
# Options:
#   -s, --size SIZE     Size of boot image in MB (default: 50)
#   -o, --output FILE   Output image filename (default: boot.img)
#   -k, --kernel PATH   Path to kernel bzImage (default: ./myiso/bzImage)
#   -i, --initrd PATH   Path to initramfs (default: ./myiso/initramfs)
#   -c, --config PATH   Path to syslinux config (default: ./myiso/isolinux/isolinux.cfg)
#   -h, --help          Show this help message
#   -v, --verbose       Enable verbose output
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# Configuration and Default Values
# -----------------------------------------------------------------------------
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default configuration
IMAGE_SIZE=50
OUTPUT_IMAGE="boot.img"
KERNEL_PATH="./myiso/bzImage"
INITRAMFS_PATH="./myiso/initramfs"
SYSLINUX_CONFIG="./myiso/isolinux/isolinux.cfg"
MOUNT_POINT="mnt"
VERBOSE=false

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Logging Functions
# -----------------------------------------------------------------------------
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_verbose() {
    if [[ "${VERBOSE}" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $*"
    fi
}

# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------
show_help() {
    cat << EOF
${SCRIPT_NAME} - Build bootable disk image for custom Linux distribution

USAGE:
    ${SCRIPT_NAME} [OPTIONS]

OPTIONS:
    -s, --size SIZE       Size of boot image in MB (default: ${IMAGE_SIZE})
    -o, --output FILE     Output image filename (default: ${OUTPUT_IMAGE})
    -k, --kernel PATH     Path to kernel bzImage (default: ${KERNEL_PATH})
    -i, --initrd PATH     Path to initramfs (default: ${INITRAMFS_PATH})
    -c, --config PATH     Path to syslinux config (default: ${SYSLINUX_CONFIG})
    -h, --help            Show this help message
    -v, --verbose         Enable verbose output

EXAMPLES:
    # Build with default settings
    ${SCRIPT_NAME}

    # Build with custom size
    ${SCRIPT_NAME} --size 100

    # Build with custom output name
    ${SCRIPT_NAME} --output my-custom-boot.img

DESCRIPTION:
    This script creates a bootable FAT-formatted disk image containing:
    - Linux kernel (bzImage)
    - Initial RAM filesystem (initramfs)
    - Syslinux bootloader

    The resulting image can be booted with QEMU or written to a USB drive.

EOF
}

# Check if required commands exist
check_dependencies() {
    local deps=("dd" "mkfs.fat" "syslinux" "mount" "umount")
    local missing=()

    log_verbose "Checking dependencies..."

    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing[*]}"
        log_error "Please install: ${missing[*]}"
        return 1
    fi

    log_verbose "All dependencies found"
    return 0
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_warning "This script may require root privileges for mounting"
        log_warning "If you encounter permission errors, run with sudo"
    fi
}

# Validate file exists
validate_file() {
    local file="$1"
    local description="$2"

    if [[ ! -f "$file" ]]; then
        log_error "${description} not found: ${file}"
        return 1
    fi
    log_verbose "${description} found: ${file}"
    return 0
}

# Cleanup function
cleanup() {
    local exit_code=$?

    log_verbose "Running cleanup..."

    # Unmount if still mounted
    if mountpoint -q "${MOUNT_POINT}" 2>/dev/null; then
        log_info "Unmounting ${MOUNT_POINT}..."
        umount "${MOUNT_POINT}" || log_warning "Failed to unmount ${MOUNT_POINT}"
    fi

    # Remove mount point if it exists and is empty
    if [[ -d "${MOUNT_POINT}" ]]; then
        rmdir "${MOUNT_POINT}" 2>/dev/null || log_verbose "Mount point not removed (may not be empty)"
    fi

    if [[ $exit_code -ne 0 ]]; then
        log_error "Build failed with exit code: ${exit_code}"
    fi

    exit $exit_code
}

# -----------------------------------------------------------------------------
# Main Build Functions
# -----------------------------------------------------------------------------

# Create disk image
create_disk_image() {
    log_info "Creating ${IMAGE_SIZE}MB disk image: ${OUTPUT_IMAGE}..."

    if [[ -f "${OUTPUT_IMAGE}" ]]; then
        log_warning "Output file already exists: ${OUTPUT_IMAGE}"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Aborted by user"
            return 1
        fi
        rm -f "${OUTPUT_IMAGE}"
    fi

    dd if=/dev/zero of="${OUTPUT_IMAGE}" bs=1M count="${IMAGE_SIZE}" status=progress 2>&1 | \
        grep -v "records" || true

    log_success "Disk image created"
}

# Format disk image with FAT filesystem
format_disk_image() {
    log_info "Formatting disk image with FAT filesystem..."
    mkfs.fat "${OUTPUT_IMAGE}" > /dev/null
    log_success "Disk image formatted"
}

# Install syslinux bootloader
install_bootloader() {
    log_info "Installing Syslinux bootloader..."
    syslinux "${OUTPUT_IMAGE}"
    log_success "Bootloader installed"
}

# Mount disk image
mount_disk_image() {
    log_info "Mounting disk image..."

    if [[ -d "${MOUNT_POINT}" ]]; then
        if mountpoint -q "${MOUNT_POINT}"; then
            log_warning "Mount point already in use"
            return 1
        fi
    else
        mkdir -p "${MOUNT_POINT}"
    fi

    mount "${OUTPUT_IMAGE}" "${MOUNT_POINT}"
    log_success "Disk image mounted at ${MOUNT_POINT}"
}

# Copy files to disk image
copy_files() {
    log_info "Copying files to disk image..."

    log_verbose "Copying kernel: ${KERNEL_PATH}"
    cp "${KERNEL_PATH}" "${MOUNT_POINT}/bzImage"

    log_verbose "Copying initramfs: ${INITRAMFS_PATH}"
    cp "${INITRAMFS_PATH}" "${MOUNT_POINT}/initramfs"

    log_verbose "Copying syslinux config: ${SYSLINUX_CONFIG}"
    cp "${SYSLINUX_CONFIG}" "${MOUNT_POINT}/syslinux.cfg"

    log_success "Files copied successfully"
}

# Unmount disk image
unmount_disk_image() {
    log_info "Unmounting disk image..."
    umount "${MOUNT_POINT}"
    rmdir "${MOUNT_POINT}"
    log_success "Disk image unmounted"
}

# -----------------------------------------------------------------------------
# Argument Parsing
# -----------------------------------------------------------------------------
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--size)
                IMAGE_SIZE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_IMAGE="$2"
                shift 2
                ;;
            -k|--kernel)
                KERNEL_PATH="$2"
                shift 2
                ;;
            -i|--initrd)
                INITRAMFS_PATH="$2"
                shift 2
                ;;
            -c|--config)
                SYSLINUX_CONFIG="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------
main() {
    # Set up cleanup trap
    trap cleanup EXIT INT TERM

    # Parse command line arguments
    parse_arguments "$@"

    # Print configuration
    log_info "Starting build process..."
    log_verbose "Configuration:"
    log_verbose "  Image Size: ${IMAGE_SIZE}MB"
    log_verbose "  Output: ${OUTPUT_IMAGE}"
    log_verbose "  Kernel: ${KERNEL_PATH}"
    log_verbose "  Initramfs: ${INITRAMFS_PATH}"
    log_verbose "  Syslinux Config: ${SYSLINUX_CONFIG}"

    # Check dependencies
    check_dependencies
    check_root

    # Validate input files
    validate_file "${KERNEL_PATH}" "Kernel image"
    validate_file "${INITRAMFS_PATH}" "Initramfs"
    validate_file "${SYSLINUX_CONFIG}" "Syslinux config"

    # Build process
    create_disk_image
    format_disk_image
    install_bootloader
    mount_disk_image
    copy_files
    unmount_disk_image

    log_success "Build completed successfully!"
    log_info "Boot image created: ${OUTPUT_IMAGE}"
    log_info ""
    log_info "To test with QEMU, run:"
    log_info "  qemu-system-x86_64 ${OUTPUT_IMAGE}"
}

# Run main function
main "$@"
