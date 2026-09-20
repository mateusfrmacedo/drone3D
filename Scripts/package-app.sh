#!/bin/zsh
set -euo pipefail

if (( $# < 1 || $# > 2 )); then
    print "Usage: $0 arm64 [output-directory]"
    exit 64
fi

ARCHITECTURE="$1"
case "$ARCHITECTURE" in
    arm64)
        APP_NAME="Drone3D-AppleSilicon"
        ;;
    *)
        print "Drone3D now supports Apple Silicon (arm64) only."
        exit 64
        ;;
esac

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIRECTORY="$(cd "$SCRIPT_DIRECTORY/.." && pwd)"
OUTPUT_DIRECTORY="${2:-$PROJECT_DIRECTORY/Distribution}"
APP_DIRECTORY="$OUTPUT_DIRECTORY/$APP_NAME.app"
BUILD_DIRECTORY="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIRECTORY"' EXIT

if [[ -e "$APP_DIRECTORY" ]]; then
    print "Refusing to overwrite existing app: $APP_DIRECTORY"
    exit 1
fi


cd "$PROJECT_DIRECTORY"
swift build -c release --arch "$ARCHITECTURE"

EXECUTABLE="$(swift build -c release --arch "$ARCHITECTURE" --show-bin-path)/Drone3D"
if [[ ! -x "$EXECUTABLE" ]]; then
    print "Swift did not produce the expected executable: $EXECUTABLE"
    exit 1
fi

mkdir -p "$BUILD_DIRECTORY/$APP_NAME.app/Contents/MacOS"
mkdir -p "$BUILD_DIRECTORY/$APP_NAME.app/Contents/Resources"
ditto "$EXECUTABLE" "$BUILD_DIRECTORY/$APP_NAME.app/Contents/MacOS/Drone3D"

sed "s/__ARCH__/$ARCHITECTURE/" "$PROJECT_DIRECTORY/Resources/Info.plist.template" > "$BUILD_DIRECTORY/$APP_NAME.app/Contents/Info.plist"

xcrun actool "$PROJECT_DIRECTORY/Drone3D.icon" \
    --compile "$BUILD_DIRECTORY/$APP_NAME.app/Contents/Resources" \
    --output-format human-readable-text \
    --app-icon Drone3D \
    --include-all-app-icons \
    --enable-on-demand-resources NO \
    --development-region en \
    --target-device mac \
    --minimum-deployment-target 26.0 \
    --output-partial-info-plist "$BUILD_DIRECTORY/asset-info.plist" \
    --platform macosx >/dev/null


codesign --force --deep --sign - "$BUILD_DIRECTORY/$APP_NAME.app" >/dev/null
mkdir -p "$OUTPUT_DIRECTORY"
ditto "$BUILD_DIRECTORY/$APP_NAME.app" "$APP_DIRECTORY"
print "Created: $APP_DIRECTORY"
