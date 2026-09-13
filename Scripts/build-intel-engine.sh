#!/bin/zsh
set -euo pipefail

if (( $# != 1 )); then
    print "Usage: $0 <output-directory>"
    exit 64
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
    print "Build the Intel engine on an Intel Mac. This script intentionally does not produce a cross-compiled release."
    exit 1
fi

OUTPUT_DIRECTORY="$1"
if [[ -e "$OUTPUT_DIRECTORY" ]]; then
    print "Refusing to overwrite existing output: $OUTPUT_DIRECTORY"
    exit 1
fi

WORK_DIRECTORY="$(mktemp -d)"
trap 'rm -rf "$WORK_DIRECTORY"' EXIT
VCPKG_DIRECTORY="$WORK_DIRECTORY/vcpkg"
TRIPLET="x64-osx"

print "Downloading the reproducible Intel build dependencies…"
git clone --depth 1 https://github.com/microsoft/vcpkg.git "$VCPKG_DIRECTORY"
"$VCPKG_DIRECTORY/bootstrap-vcpkg.sh" -disableMetrics

print "Building COLMAP and OpenMVS for Intel. This can take a long time."
"$VCPKG_DIRECTORY/vcpkg" install \
    --triplet "$TRIPLET" \
    --x-no-default-features \
    colmap \
    "openmvs[tools]"

PREFIX="$VCPKG_DIRECTORY/installed/$TRIPLET"
mkdir -p "$OUTPUT_DIRECTORY/bin" "$OUTPUT_DIRECTORY/lib" "$OUTPUT_DIRECTORY/licenses"

copy_tool() {
    local tool="$1"
    local source
    source="$(find "$PREFIX/tools" -type f -name "$tool" -perm -111 -print -quit)"
    if [[ -z "$source" ]]; then
        print "Required tool was not installed: $tool"
        exit 1
    fi
    ditto "$source" "$OUTPUT_DIRECTORY/bin/$tool"
}

for TOOL in colmap InterfaceCOLMAP DensifyPointCloud ReconstructMesh RefineMesh TextureMesh; do
    copy_tool "$TOOL"
done

find "$PREFIX/lib" -type f -name '*.dylib' -exec ditto {} "$OUTPUT_DIRECTORY/lib" \;
if [[ -d "$PREFIX/lib/colmap" ]]; then
    ditto "$PREFIX/lib/colmap" "$OUTPUT_DIRECTORY/lib/colmap"
fi
if [[ -d "$PREFIX/share/colmap" ]]; then
    ditto "$PREFIX/share/colmap" "$OUTPUT_DIRECTORY/licenses/COLMAP"
fi
if [[ -d "$PREFIX/share/openmvs" ]]; then
    ditto "$PREFIX/share/openmvs" "$OUTPUT_DIRECTORY/licenses/OpenMVS"
fi

print "Intel engine created: $OUTPUT_DIRECTORY"
