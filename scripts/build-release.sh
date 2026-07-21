#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
ARCH="$(uname -m)"
VERSION="${VERSION:-0.1.0}"
APP_DIR="$PROJECT_DIR/build/Audio Delay.app"
RELEASE_DIR="$PROJECT_DIR/release"
ARCHIVE="$RELEASE_DIR/audio-delay-macos-${ARCH}.zip"

"$SCRIPT_DIR/build-app.sh"
mkdir -p "$RELEASE_DIR"
rm -f "$ARCHIVE"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ARCHIVE"

shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256"
echo "Release archive: $ARCHIVE"
