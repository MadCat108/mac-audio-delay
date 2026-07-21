#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/Audio Delay.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_SOURCE="$PROJECT_DIR/Resources/AppIcon.icns"
UPDATER_INFO_SOURCE="$PROJECT_DIR/Resources/UpdaterInfo.plist"
UPDATE_SCRIPT_SOURCE="$PROJECT_DIR/scripts/update.sh"
VERSION_FILE="$PROJECT_DIR/VERSION"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "Version file is missing: $VERSION_FILE" >&2
  exit 1
fi
APP_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
if [[ ! "$APP_VERSION" =~ '^[0-9]+(\.[0-9]+)+$' ]]; then
  echo "Invalid application version: $APP_VERSION" >&2
  exit 1
fi

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$PROJECT_DIR/.build-cache/clang}"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

cd "$PROJECT_DIR"

DEVELOPER_PATH="${DEVELOPER_DIR:-$(xcode-select -p)}"
SDK_PATH="$(DEVELOPER_DIR="$DEVELOPER_PATH" xcrun --sdk macosx --show-sdk-path)"
SWIFT_COMPILER="$(DEVELOPER_DIR="$DEVELOPER_PATH" xcrun --find swiftc)"
CLANG_COMPILER="$(DEVELOPER_DIR="$DEVELOPER_PATH" xcrun --find clang++)"

# Some internal Xcode installations keep the SDK-matching macOS compiler in a
# separate OSX*.xctoolchain while SwiftPM remains in the default toolchain.
matching_compilers=("$DEVELOPER_PATH"/Toolchains/OSX*.xctoolchain/usr/bin/swiftc(N))
if (( ${#matching_compilers} > 0 )); then
  SWIFT_COMPILER="${matching_compilers[-1]}"
fi

# Compile directly instead of invoking Swift Package Manager. Some otherwise
# usable Command Line Tools installations contain a mismatched PackageDescription
# library, which prevents SwiftPM from reading Package.swift even though swiftc
# and clang can build the application correctly.
BIN_DIR="$PROJECT_DIR/.build-app-direct"
rm -rf "$BIN_DIR"
mkdir -p "$BIN_DIR"

TARGET="$(uname -m)-apple-macos14.2"
CORE_INCLUDE_DIR="$PROJECT_DIR/Sources/AudioDelayCore/include"
CORE_OBJECT="$BIN_DIR/AudioDelayCore.o"

echo "Building for production..."

"$CLANG_COMPILER" \
  -std=c++17 \
  -O \
  -mmacosx-version-min=14.2 \
  -isysroot "$SDK_PATH" \
  -I "$CORE_INCLUDE_DIR" \
  -c "$PROJECT_DIR/Sources/AudioDelayCore/AudioDelayCore.cpp" \
  -o "$CORE_OBJECT"

"$SWIFT_COMPILER" \
  -O \
  -whole-module-optimization \
  -parse-as-library \
  -sdk "$SDK_PATH" \
  -target "$TARGET" \
  -module-cache-path "$CLANG_MODULE_CACHE_PATH" \
  -I "$CORE_INCLUDE_DIR" \
  "$PROJECT_DIR"/Sources/AudioDelay/*.swift \
  "$CORE_OBJECT" \
  -lc++ \
  -framework CoreAudio \
  -o "$BIN_DIR/AudioDelay"

echo "Build of product 'AudioDelay' complete!"

"$SWIFT_COMPILER" \
  -O \
  -parse-as-library \
  -sdk "$SDK_PATH" \
  -target "$TARGET" \
  -module-cache-path "$CLANG_MODULE_CACHE_PATH" \
  "$PROJECT_DIR/Sources/AudioDelayUpdater/main.swift" \
  -o "$BIN_DIR/AudioDelayUpdater"

echo "Build of product 'AudioDelayUpdater' complete!"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_DIR/AudioDelay" "$MACOS_DIR/AudioDelay"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy \
  -c "Set :CFBundleShortVersionString $APP_VERSION" \
  "$CONTENTS_DIR/Info.plist"
chmod 755 "$MACOS_DIR/AudioDelay"

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "App icon source is missing: $ICON_SOURCE" >&2
  exit 1
fi

cp "$ICON_SOURCE" "$RESOURCES_DIR/AppIcon.icns"
if [[ ! -f "$UPDATER_INFO_SOURCE" ]]; then
  echo "Updater Info.plist is missing: $UPDATER_INFO_SOURCE" >&2
  exit 1
fi
UPDATER_APP_DIR="$RESOURCES_DIR/Audio Delay Updater.app"
UPDATER_CONTENTS_DIR="$UPDATER_APP_DIR/Contents"
UPDATER_MACOS_DIR="$UPDATER_CONTENTS_DIR/MacOS"
UPDATER_RESOURCES_DIR="$UPDATER_CONTENTS_DIR/Resources"
mkdir -p "$UPDATER_MACOS_DIR" "$UPDATER_RESOURCES_DIR"
cp "$BIN_DIR/AudioDelayUpdater" "$UPDATER_MACOS_DIR/AudioDelayUpdater"
cp "$UPDATER_INFO_SOURCE" "$UPDATER_CONTENTS_DIR/Info.plist"
cp "$ICON_SOURCE" "$UPDATER_RESOURCES_DIR/AppIcon.icns"
/usr/libexec/PlistBuddy \
  -c "Set :CFBundleShortVersionString $APP_VERSION" \
  "$UPDATER_CONTENTS_DIR/Info.plist"
chmod 755 "$UPDATER_MACOS_DIR/AudioDelayUpdater"
codesign --force --deep --sign - "$UPDATER_APP_DIR"
if [[ ! -f "$UPDATE_SCRIPT_SOURCE" ]]; then
  echo "Update helper is missing: $UPDATE_SCRIPT_SOURCE" >&2
  exit 1
fi
cp "$UPDATE_SCRIPT_SOURCE" "$RESOURCES_DIR/update.sh"
chmod 755 "$RESOURCES_DIR/update.sh"

codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

echo
echo "Built: $APP_DIR"
