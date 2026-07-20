#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
BUILD_ROOT="${SOX_BUILD_ROOT:-$PROJECT_DIR/.build-dependencies/sox}"
SOURCE_DIR="$BUILD_ROOT/source/sox-14.4.2"
INSTALL_DIR="$BUILD_ROOT/install"
SOX_BINARY="$INSTALL_DIR/bin/sox"
ARCHIVE="$BUILD_ROOT/source/sox-14.4.2.tar.gz"
SOURCE_URL="https://downloads.sourceforge.net/project/sox/sox/14.4.2/sox-14.4.2.tar.gz"
SOURCE_SHA256="b45f598643ffbd8e363ff24d61166ccec4836fea6d3888881b8df53e3bb55f6c"

supports_coreaudio() {
  local output
  output="$("$1" --help-format coreaudio 2>&1 || true)"
  [[ "$output" == *"Format: coreaudio"* ]]
}

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "This installer currently supports Apple Silicon Macs only." >&2
  exit 1
fi

if [[ -x "$SOX_BINARY" ]] && supports_coreaudio "$SOX_BINARY"; then
  echo "$SOX_BINARY"
  exit 0
fi

for tool in curl make clang tar shasum; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Required build tool is unavailable: $tool" >&2
    exit 1
  fi
done

mkdir -p "$BUILD_ROOT/source"

echo "Downloading the official SoX 14.4.2 source..." >&2
curl --fail --location --silent --show-error \
  --proto '=https' --tlsv1.2 \
  "$SOURCE_URL" -o "$ARCHIVE"

actual_sha="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
if [[ "$actual_sha" != "$SOURCE_SHA256" ]]; then
  echo "SoX source checksum verification failed." >&2
  echo "Expected: $SOURCE_SHA256" >&2
  echo "Received: $actual_sha" >&2
  exit 1
fi

rm -rf "$SOURCE_DIR" "$INSTALL_DIR"
tar -xzf "$ARCHIVE" -C "$BUILD_ROOT/source"

echo "Building the minimal CoreAudio-only SoX helper..." >&2
cd "$SOURCE_DIR"

# Keep the build independent of Homebrew even when Homebrew happens to be
# installed on the maintainer's Mac.
PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
  CC=/usr/bin/clang \
  CFLAGS="-O2 -Wno-incompatible-function-pointer-types" \
  PKG_CONFIG_PATH="" \
  ./configure \
    --prefix="$INSTALL_DIR" \
    --disable-shared \
    --enable-static \
    --disable-openmp \
    --disable-symlinks \
    --without-libltdl \
    --without-magic \
    --without-png \
    --without-ladspa \
    --without-mad \
    --without-id3tag \
    --without-lame \
    --without-twolame \
    --without-oggvorbis \
    --without-opus \
    --without-flac \
    --without-amrwb \
    --without-amrnb \
    --without-wavpack \
    --without-sndio \
    --without-ao \
    --without-pulseaudio \
    --without-waveaudio \
    --without-sndfile \
    --without-oss \
    --without-sunaudio \
    --without-gsm \
    --without-lpc10 \
    >"$BUILD_ROOT/configure.log" 2>&1

PATH="/usr/bin:/bin:/usr/sbin:/sbin" make -s -j4 \
  >"$BUILD_ROOT/build.log" 2>&1
PATH="/usr/bin:/bin:/usr/sbin:/sbin" make -s install \
  >>"$BUILD_ROOT/build.log" 2>&1

if [[ ! -x "$SOX_BINARY" ]] || ! supports_coreaudio "$SOX_BINARY"; then
  echo "The locally built SoX helper failed its CoreAudio check." >&2
  exit 1
fi

echo "$SOX_BINARY"
