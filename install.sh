#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
APP_SOURCE="$SCRIPT_DIR/build/Audio Delay.app"
INSTALL_DIR="${AUDIO_DELAY_INSTALL_DIR:-$HOME/Applications}"
APP_DEST="$INSTALL_DIR/Audio Delay.app"
MINIMUM_MACOS_MAJOR=14

has_vb_cable() {
  [[ -d /Library/Audio/Plug-Ins/HAL/VBCable.driver ]] || \
    system_profiler SPAudioDataType 2>/dev/null | grep -qi 'VB-Cable'
}

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "Audio Delay currently supports Apple Silicon Macs only." >&2
  exit 1
fi

macos_major="$(sw_vers -productVersion | cut -d. -f1)"
if (( macos_major < MINIMUM_MACOS_MAJOR )); then
  echo "Audio Delay requires macOS 14 or newer." >&2
  exit 1
fi

if ! xcrun --find swift >/dev/null 2>&1 || ! xcrun --find clang >/dev/null 2>&1; then
  echo "Apple Command Line Tools are required to build Audio Delay."
  echo "macOS will now open Apple's installer."
  xcode-select --install >/dev/null 2>&1 || true

  echo "Waiting for Apple Command Line Tools to finish installing..."
  for _ in {1..360}; do
    if xcrun --find swift >/dev/null 2>&1 && xcrun --find clang >/dev/null 2>&1; then
      break
    fi
    sleep 5
  done

  if ! xcrun --find swift >/dev/null 2>&1 || ! xcrun --find clang >/dev/null 2>&1; then
    echo "Apple Command Line Tools did not finish installing." >&2
    echo "Run this setup again after their installation completes." >&2
    exit 1
  fi
fi

if ! has_vb_cable && [[ "${AUDIO_DELAY_SKIP_VB_CABLE:-0}" != "1" ]]; then
  "$SCRIPT_DIR/scripts/install-vb-cable.sh"
fi

echo "Building Audio Delay locally on this Mac..."
"$SCRIPT_DIR/scripts/build-app.sh"

mkdir -p "$INSTALL_DIR"
if [[ -d "$APP_DEST" ]]; then
  backup="$HOME/.Trash/Audio Delay-$(date +%Y%m%d-%H%M%S).app"
  mv "$APP_DEST" "$backup"
  echo "Moved the previous app to: $backup"
fi
ditto "$APP_SOURCE" "$APP_DEST"

echo "Installed: $APP_DEST"
if [[ "${AUDIO_DELAY_NO_OPEN:-0}" != "1" ]]; then
  open "$APP_DEST"
fi
