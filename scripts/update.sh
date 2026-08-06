#!/bin/zsh

set -u

REPOSITORY="${AUDIO_DELAY_GITHUB_REPOSITORY:-MadCat108/mac-audio-delay}"
SCRIPT_PATH="${0:A}"
LOG_DIR="$HOME/Library/Logs"
LOG_FILE="$LOG_DIR/Audio Delay Update.log"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/audio-delay-update.XXXXXX")"
BOOTSTRAP="$TMP_DIR/bootstrap.sh"

mkdir -p "$LOG_DIR"
if [[ "${AUDIO_DELAY_UPDATE_FOREGROUND:-0}" == "1" ]]; then
  exec > >(tee "$LOG_FILE") 2>&1
else
  exec >"$LOG_FILE" 2>&1
fi

cleanup() {
  rm -rf "$TMP_DIR"
  if [[ "$SCRIPT_PATH" == "${TMPDIR:-/tmp}"/audio-delay-update-*.sh ]]; then
    rm -f "$SCRIPT_PATH"
  fi
}
trap cleanup EXIT

echo "Audio Delay update started at $(date)"
echo "System: macOS $(sw_vers -productVersion) (build $(sw_vers -buildVersion), $(uname -m))"
if [[ "${AUDIO_DELAY_UPDATE_FOREGROUND:-0}" != "1" ]]; then
  /usr/bin/osascript \
    -e 'display notification "The app will reopen when the update is complete." with title "Updating Audio Delay"' \
    >/dev/null 2>&1 || true
fi

exit_code=0
curl --fail --location --silent --show-error \
  --proto '=https' --tlsv1.2 \
  "https://raw.githubusercontent.com/$REPOSITORY/main/bootstrap.sh" \
  -o "$BOOTSTRAP" || exit_code=$?

if (( exit_code == 0 )); then
  /bin/zsh "$BOOTSTRAP" || exit_code=$?
fi

if (( exit_code == 0 )); then
  echo "Audio Delay update completed at $(date)"
  if [[ "${AUDIO_DELAY_UPDATE_FOREGROUND:-0}" != "1" ]]; then
    /usr/bin/osascript \
      -e 'display notification "The latest version is installed." with title "Audio Delay Updated"' \
      >/dev/null 2>&1 || true
  fi
  exit 0
fi

echo "Audio Delay update failed with status $exit_code at $(date)"
if [[ "${AUDIO_DELAY_UPDATE_FOREGROUND:-0}" != "1" ]]; then
  /usr/bin/osascript \
    -e 'display alert "Audio Delay update failed" message "Run the installer command again, or review Audio Delay Update.log in your Library/Logs folder." as critical buttons {"OK"} default button "OK"' \
    >/dev/null 2>&1 || true
fi
exit "$exit_code"
