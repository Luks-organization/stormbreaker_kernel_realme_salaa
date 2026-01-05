#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Colors for output
GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m" # No Color

function log() {
    echo -e "${GREEN}[*] $1${NC}"
}

function error_exit() {
    echo -e "${RED}[!] $1${NC}" >&2
    exit 1
}

function download_toolchains() {
    log "Downloading and setting up toolchains..."

    if [ ! -d "clang" ]; then
        git clone --depth=1 https://gitlab.com/LeCmnGend/clang.git -b clang-19 clang
    fi
}

function compile_kernel() {
    log "Starting kernel compilation..."

    make clean && make mrproper
    rm -rf out AnyKernel
    mkdir -p out

    source ~/.bashrc || true
    source ~/.profile || true

    export LC_ALL=C
    export ARCH=arm64
    export USE_CCACHE=1
    export CCACHE_COMPRESS=1
    export CCACHE_EXEC=/usr/bin/ccache
    export CCACHE_DIR=~/.ccache
    ccache -M 50G
    ccache -o compression=true

    make O=out ARCH=arm64 salaa_defconfig

    PATH="${PWD}/clang/bin:${PATH}" \

    make -j$(nproc --all) O=out \
        ARCH=arm64 \
        CC="clang" \
        LLVM=1 \
        CONFIG_NO_ERROR_ON_MISMATCH=y \
        2>&1 | tee error.log || error_exit "Kernel build failed. Check error.log"
}

function zip_kernel() {
    log "Zipping kernel..."

    DATE=$(date "+%d%m%Y")
    KERNEL_IMAGE="out/arch/arm64/boot/Image.gz-dtb"

    if [ ! -f "$KERNEL_IMAGE" ]; then
        error_exit "Kernel image not found at $KERNEL_IMAGE"
    fi

    git clone --depth=1 https://github.com/Luks-organization/AnyKernel3 AnyKernel || error_exit "Failed to clone AnyKernel3"
    cp "$KERNEL_IMAGE" AnyKernel || error_exit "Failed to copy kernel image"
    cd AnyKernel || exit
    zip -r9 4.14.356-${DATE}-salaa.zip * || error_exit "Zipping failed"
    log "Kernel zip created: AnyKernel/4.14.356-${DATE}-salaa.zip"
}

function main() {
    log "On upstream-xx branch"
    download_toolchains
    compile_kernel
    zip_kernel
}

main "$@"
