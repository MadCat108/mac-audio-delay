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
SOX_PATH="${SOX_PATH:-}"
LOCAL_SOX=false

if [[ -z "$SOX_PATH" ]]; then
  SOX_PATH="$("$SCRIPT_DIR/build-sox.sh")"
  LOCAL_SOX=true
fi

if [[ ! -x "$SOX_PATH" ]]; then
  echo "SoX is not executable: $SOX_PATH" >&2
  exit 1
fi

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
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-$CLANG_MODULE_CACHE_PATH}"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

cd "$PROJECT_DIR"

DEVELOPER_PATH="${DEVELOPER_DIR:-$(xcode-select -p)}"
SWIFT_DRIVER="$(DEVELOPER_DIR="$DEVELOPER_PATH" xcrun --find swift)"
SWIFT_ENV=(
  "DEVELOPER_DIR=$DEVELOPER_PATH"
  "CLANG_MODULE_CACHE_PATH=$CLANG_MODULE_CACHE_PATH"
  "SWIFTPM_MODULECACHE_OVERRIDE=$SWIFTPM_MODULECACHE_OVERRIDE"
)

# Some internal Xcode installations keep the SDK-matching macOS compiler in a
# separate OSX*.xctoolchain while SwiftPM remains in the default toolchain.
matching_compilers=("$DEVELOPER_PATH"/Toolchains/OSX*.xctoolchain/usr/bin/swiftc(N))
if (( ${#matching_compilers} > 0 )); then
  SWIFT_ENV+=("SWIFT_EXEC=${matching_compilers[-1]}")
fi

SCRATCH_PATH="$PROJECT_DIR/.build-app"
env $SWIFT_ENV "$SWIFT_DRIVER" build -c release --disable-sandbox \
  --scratch-path "$SCRATCH_PATH" --product AudioDelay
env $SWIFT_ENV "$SWIFT_DRIVER" build -c release --disable-sandbox \
  --scratch-path "$SCRATCH_PATH" --product AudioDelayUpdater
BIN_DIR="$(env $SWIFT_ENV "$SWIFT_DRIVER" build -c release --disable-sandbox \
  --scratch-path "$SCRATCH_PATH" --show-bin-path)"

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

if $LOCAL_SOX; then
  cp "$SOX_PATH" "$RESOURCES_DIR/sox"
  chmod 755 "$RESOURCES_DIR/sox"
  mkdir -p "$RESOURCES_DIR/licenses/sox"
  SOX_SOURCE_DIR="$PROJECT_DIR/.build-dependencies/sox/source/sox-14.4.2"
  cp "$SOX_SOURCE_DIR/LICENSE.GPL" "$RESOURCES_DIR/licenses/sox/"
  cp "$SOX_SOURCE_DIR/LICENSE.LGPL" "$RESOURCES_DIR/licenses/sox/"
  cp "$SOX_SOURCE_DIR/COPYING" "$RESOURCES_DIR/licenses/sox/"
  codesign --force --sign - "$RESOURCES_DIR/sox"
else
  "$SCRIPT_DIR/bundle-sox.sh" "$SOX_PATH" "$RESOURCES_DIR"
fi

codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

echo
echo "Built: $APP_DIR"
