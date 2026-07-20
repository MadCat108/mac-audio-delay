#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
DOWNLOAD_URL="https://download.vb-audio.com/Download_MAC/VBCable_MACDriver_Pack108.zip"
DOWNLOAD_SHA256="e46b41c6876995403cb1da37d7c0d566f59edd83aa9fcbcdc3a205eb0b6e05c7"
EXPECTED_TEAM="Developer ID Installer: Vincent Burel (6K8JQXLBSY)"
VERIFY_ONLY=false

if [[ "${1:-}" == "--verify-only" ]]; then
  VERIFY_ONLY=true
elif [[ $# -ne 0 ]]; then
  echo "Usage: $0 [--verify-only]" >&2
  exit 64
fi

has_vb_cable() {
  [[ -d /Library/Audio/Plug-Ins/HAL/VBCable.driver ]] || \
    system_profiler SPAudioDataType 2>/dev/null | grep -qi 'VB-Cable'
}

if ! $VERIFY_ONLY && has_vb_cable; then
  echo "VB-CABLE is already installed."
  exit 0
fi

if ! $VERIFY_ONLY; then
  /usr/bin/osascript -l JavaScript "$SCRIPT_DIR/vb-cable-consent.js" >/dev/null
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/audio-delay-vbcable.XXXXXX")"
MOUNT_DIR="$TMP_DIR/mount"
MOUNTED=false

cleanup() {
  if $MOUNTED; then
    /usr/bin/hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$MOUNT_DIR" "$TMP_DIR/unpacked"
archive="$TMP_DIR/VBCable_MACDriver_Pack108.zip"

echo "Downloading VB-CABLE from VB-Audio..."
/usr/bin/curl --fail --location --silent --show-error \
  --proto '=https' --tlsv1.2 \
  "$DOWNLOAD_URL" -o "$archive"

actual_sha="$(/usr/bin/shasum -a 256 "$archive" | /usr/bin/awk '{print $1}')"
if [[ "$actual_sha" != "$DOWNLOAD_SHA256" ]]; then
  echo "VB-CABLE checksum verification failed; installation was cancelled." >&2
  echo "Expected: $DOWNLOAD_SHA256" >&2
  echo "Received: $actual_sha" >&2
  exit 1
fi

/usr/bin/ditto -x -k "$archive" "$TMP_DIR/unpacked"
dmg="$TMP_DIR/unpacked/VBCable_MACDriver_Pack108.dmg"
if [[ ! -f "$dmg" ]]; then
  echo "The verified archive does not contain the Apple Silicon VB-CABLE DMG." >&2
  exit 1
fi

/usr/bin/hdiutil verify "$dmg" >/dev/null
/usr/bin/hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT_DIR" "$dmg" >/dev/null
MOUNTED=true

package="$MOUNT_DIR/vb-cable-installer.pkg"
if [[ ! -f "$package" ]]; then
  echo "The official VB-CABLE installer package was not found." >&2
  exit 1
fi

signature="$(/usr/sbin/pkgutil --check-signature "$package" 2>&1)"
if [[ "$signature" != *"$EXPECTED_TEAM"* ]] || \
  [[ "$signature" != *"Notarization: trusted by the Apple notary service"* ]]; then
  echo "VB-CABLE's installer signature did not match the expected developer." >&2
  exit 1
fi

/usr/sbin/spctl --assess --type install "$package"

if $VERIFY_ONLY; then
  echo "VB-CABLE download, checksum, notarization, and installer signature verified."
  exit 0
fi

echo "macOS will now request administrator approval for the VB-CABLE driver."
/usr/bin/osascript -l JavaScript "$SCRIPT_DIR/vb-cable-admin-install.js" "$package"

if ! has_vb_cable; then
  echo "VB-CABLE installation finished, but the audio driver was not detected." >&2
  exit 1
fi

echo "VB-CABLE installed successfully."
