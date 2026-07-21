#!/bin/zsh

set -euo pipefail

REPOSITORY="${AUDIO_DELAY_GITHUB_REPOSITORY:-MadCat108/mac-audio-delay}"
ARCH="$(uname -m)"

if [[ "$ARCH" != "arm64" ]]; then
  echo "Audio Delay currently supports Apple Silicon Macs only." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/audio-delay.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

SOURCE_ARCHIVE="$TMP_DIR/source.tar.gz"
SOURCE_DIR="$TMP_DIR/source"

echo "Downloading Audio Delay source from GitHub..."
curl --fail --location --silent --show-error \
  --proto '=https' --tlsv1.2 \
  "https://github.com/$REPOSITORY/archive/refs/heads/main.tar.gz" \
  -o "$SOURCE_ARCHIVE"

mkdir -p "$SOURCE_DIR"
tar -xzf "$SOURCE_ARCHIVE" -C "$SOURCE_DIR" --strip-components=1

if [[ ! -x "$SOURCE_DIR/install.sh" ]]; then
  echo "The downloaded repository does not contain its installer." >&2
  exit 1
fi
if [[ ! -f "$SOURCE_DIR/VERSION" ]]; then
  echo "The downloaded repository does not contain a version number." >&2
  exit 1
fi

SOURCE_VERSION="$(tr -d '[:space:]' < "$SOURCE_DIR/VERSION")"
if [[ ! "$SOURCE_VERSION" =~ '^[0-9]+(\.[0-9]+)+$' ]]; then
  echo "The downloaded repository contains an invalid version number." >&2
  exit 1
fi
echo "Downloaded Audio Delay version $SOURCE_VERSION."

"$SOURCE_DIR/install.sh"
