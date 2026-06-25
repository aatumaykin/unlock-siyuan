#!/bin/bash
# ponytail: no vendored source — clone upstream, apply .patches, build.
set -e
trap 'echo "Error occurred at line $LINENO. Command: $BASH_COMMAND"; exit 1' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/siyuan"
INITIAL_DIR="$(pwd)"
TARGET='all'

# Source version from VERSION file (single source of truth), allow SIYUAN_VERSION override.
# shellcheck disable=SC1091
. "$PROJECT_ROOT/VERSION"
UPSTREAM_VERSION="${SIYUAN_VERSION:-${UPSTREAM_VERSION}}"
VERSION_TAG="${UPSTREAM_VERSION}-${PATCH_REVISION}"

echo "Usage: ./linux-build.sh [--target=<target>]"
echo '  --target: amd64, arm64, or all (default: all)'
echo "  Building: v${UPSTREAM_VERSION} (unlock ${PATCH_REVISION}) → ${VERSION_TAG}"
echo

validate_target() {
    case "$1" in amd64|arm64|all) ;; *) echo "Invalid target '$1'"; exit 1 ;; esac
}
while [[ $# -gt 0 ]]; do
    case $1 in --target=*) TARGET="${1#*=}"; validate_target "$TARGET"; shift ;; *) shift ;; esac
done

echo 'Cloning upstream and applying patches'
rm -rf "$PROJECT_ROOT/build"
git clone --branch "v$UPSTREAM_VERSION" --depth=1 https://github.com/siyuan-note/siyuan.git "$BUILD_DIR"
for patch in "$PROJECT_ROOT"/.patches/*.patch; do
    git -C "$BUILD_DIR" apply "$patch"
    echo "  ✓ $(basename "$patch")"
done

echo
echo 'Building UI'
cd "$BUILD_DIR/app"
pnpm install
pnpm run build

echo
echo 'Building Kernel'
cd "$BUILD_DIR/kernel"
go version
export GO111MODULE=on GOPROXY=https://mirrors.aliyun.com/goproxy/ CGO_ENABLED=1 GOOS=linux

if [[ "$TARGET" == 'amd64' || "$TARGET" == 'all' ]]; then
    echo 'Building Kernel amd64'
    export GOARCH=amd64 CC=~/x86_64-linux-musl-cross/bin/x86_64-linux-musl-gcc
    go build -buildmode=pie --tags fts5 -v -o "../app/kernel-linux/SiYuan-Kernel" -ldflags "-s -w -extldflags -static-pie" .
fi
if [[ "$TARGET" == 'arm64' || "$TARGET" == 'all' ]]; then
    echo 'Building Kernel arm64'
    export GOARCH=arm64 CC=~/aarch64-linux-musl-cross/bin/aarch64-linux-musl-gcc
    go build -buildmode=pie --tags fts5 -v -o "../app/kernel-linux-arm64/SiYuan-Kernel" -ldflags "-s -w -extldflags -static-pie" .
fi

echo
echo 'Building Electron App'
cd "$BUILD_DIR/app"
[[ "$TARGET" == 'amd64' || "$TARGET" == 'all' ]] && { echo 'Electron amd64'; pnpm run dist-linux; }
[[ "$TARGET" == 'arm64' || "$TARGET" == 'all' ]] && { echo 'Electron arm64'; pnpm run dist-linux-arm64; }

echo
echo '=============================='
echo '      Build successful!'
echo '=============================='
cd "$INITIAL_DIR"
