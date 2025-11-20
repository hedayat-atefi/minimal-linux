#!/usr/bin/env bash

# =============================================================================
# Extract Build Artifacts from Docker Image
# =============================================================================

set -euo pipefail

readonly IMAGE_NAME="${1:-handbuilt-linux:latest}"
readonly OUTPUT_DIR="${2:-./output}"

readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

echo -e "${BLUE}Extracting artifacts from ${IMAGE_NAME}...${NC}"

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Extract ISO
echo "Extracting ISO..."
docker run --rm "${IMAGE_NAME}" cat /distro/output.iso > "${OUTPUT_DIR}/output.iso"
echo -e "${GREEN}✓ ISO extracted: ${OUTPUT_DIR}/output.iso${NC}"

# Extract kernel
echo "Extracting kernel..."
docker run --rm "${IMAGE_NAME}" cat /distro/bzImage > "${OUTPUT_DIR}/bzImage"
echo -e "${GREEN}✓ Kernel extracted: ${OUTPUT_DIR}/bzImage${NC}"

# Extract initramfs
echo "Extracting initramfs..."
docker run --rm "${IMAGE_NAME}" cat /distro/initramfs > "${OUTPUT_DIR}/initramfs"
echo -e "${GREEN}✓ Initramfs extracted: ${OUTPUT_DIR}/initramfs${NC}"

echo -e "${GREEN}All artifacts extracted to ${OUTPUT_DIR}/${NC}"
