#!/usr/bin/env bash
# Build a release of RenderLab for one Mac architecture and zip it for a GitHub release.
#
#   ./scripts/package-release.sh v0.1.0          # this Mac's architecture
#   ./scripts/package-release.sh v0.1.0 arm64    # Apple Silicon -> dist/RenderLab-v0.1.0-macos-arm64.zip
#   ./scripts/package-release.sh v0.1.0 x86_64   # Intel         -> dist/RenderLab-v0.1.0-macos-x86_64.zip
#
# The zip holds the RenderLab executable and RenderLab_RenderLabCore.bundle (the shaders).
# They must stay side by side: the app looks for the bundle next to the executable.
# Building for the other architecture works too (cross-compiling), but only a Mac of that type can run it.
set -euo pipefail

cd "$(dirname "$0")/.."

usage() {
    echo "usage: $0 <version tag, e.g. v0.1.0> [arm64|x86_64]" >&2
    exit 2
}

version="${1:-}"
arch="${2:-$(uname -m)}"
[ -n "$version" ] || usage
case "$arch" in
    arm64 | x86_64) ;;
    *) usage ;;
esac

swift build -c release --arch "$arch"
products="$(swift build -c release --arch "$arch" --show-bin-path)"

# Refuse to package a binary for the wrong architecture.
built_archs="$(lipo -archs "$products/RenderLab")"
if [ "$built_archs" != "$arch" ]; then
    echo "expected a $arch binary, got: $built_archs" >&2
    exit 1
fi

name="RenderLab-$version-macos-$arch"
rm -rf "dist/$name" "dist/$name.zip"
mkdir -p "dist/$name"
cp -R "$products/RenderLab" "$products/RenderLab_RenderLabCore.bundle" README.md LICENSE "dist/$name/"

# ditto keeps macOS metadata and permissions the way Finder's "Compress" does.
ditto -c -k --keepParent "dist/$name" "dist/$name.zip"
echo "dist/$name.zip"
