#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
APP_SOURCE="$SCRIPT_DIR/build/Audio Delay.app"
INSTALL_DIR="${AUDIO_DELAY_INSTALL_DIR:-$HOME/Applications}"
APP_DEST="$INSTALL_DIR/Audio Delay.app"
MINIMUM_MACOS_MAJOR=14
MINIMUM_MACOS_MINOR=2

stop_running_app() {
  if ! /usr/bin/pgrep -x AudioDelay >/dev/null 2>&1; then
    return
  fi

  echo "Closing the running Audio Delay app..."
  /usr/bin/osascript \
    -e 'tell application id "org.audiodelay.utility" to quit' \
    >/dev/null 2>&1 || true

  for _ in {1..50}; do
    if ! /usr/bin/pgrep -x AudioDelay >/dev/null 2>&1; then
      return
    fi
    sleep 0.1
  done

  /usr/bin/pkill -TERM -x AudioDelay >/dev/null 2>&1 || true
}

machine_architecture="$(uname -m)"
macos_version="$(sw_vers -productVersion)"
macos_build="$(sw_vers -buildVersion)"
echo "System: macOS $macos_version (build $macos_build, $machine_architecture)"

if [[ "$machine_architecture" != "arm64" ]]; then
  echo "Audio Delay currently supports Apple Silicon Macs only." >&2
  exit 1
fi

macos_major="${macos_version%%.*}"
macos_remainder="${macos_version#*.}"
macos_minor="${macos_remainder%%.*}"
if (( macos_major < MINIMUM_MACOS_MAJOR )) || \
  (( macos_major == MINIMUM_MACOS_MAJOR && macos_minor < MINIMUM_MACOS_MINOR )); then
  echo "Audio Delay requires macOS 14.2 or newer." >&2
  exit 1
fi

stop_running_app

toolchain_commands_exist() {
  xcrun --find swift >/dev/null 2>&1 && \
    xcrun --find swiftc >/dev/null 2>&1 && \
    xcrun --find clang++ >/dev/null 2>&1
}

toolchain_is_healthy() {
  "$SCRIPT_DIR/scripts/check-toolchain.sh" --quiet
}

wait_for_command_line_tools() {
  echo "Waiting for Apple Command Line Tools to finish installing..."
  for _ in {1..360}; do
    if toolchain_commands_exist; then
      break
    fi
    sleep 5
  done

  if ! toolchain_commands_exist; then
    echo "Apple Command Line Tools did not finish installing." >&2
    echo "Run this setup again after their installation completes." >&2
    return 1
  fi

  # The compiler executables can become visible shortly before the SDK has
  # finished settling on disk. Give Apple's installer a short grace period so
  # we do not start the real build against a temporarily incomplete SDK.
  echo "Verifying the newly installed compiler and macOS SDK..."
  for _ in {1..12}; do
    if toolchain_is_healthy; then
      return 0
    fi
    sleep 5
  done

  echo "The newly installed Apple tools did not pass verification." >&2
  return 1
}

request_command_line_tools_install() {
  echo "Apple Command Line Tools are required to build Audio Delay."
  echo "macOS will now open Apple's installer."
  /usr/bin/xcode-select --install >/dev/null 2>&1 || true
  wait_for_command_line_tools
}

repair_command_line_tools() {
  local developer_path
  developer_path="$(/usr/bin/xcode-select -p 2>/dev/null || true)"
  if [[ "$developer_path" != "/Library/Developer/CommandLineTools" ]]; then
    echo >&2
    echo "Automatic repair was not offered because the selected developer tools are:" >&2
    echo "  ${developer_path:-Unknown}" >&2
    echo "Update or repair that Xcode installation, then run this installer again." >&2
    return 1
  fi

  if ! { printf "" > /dev/tty; } 2>/dev/null; then
    echo >&2
    echo "Repair requires a visible Terminal session for administrator approval." >&2
    echo "Choose “Repair in Terminal…” in the updater, or run the installer command in Terminal." >&2
    return 1
  fi

  printf "\nApple Command Line Tools need to be repaired.\n\n" > /dev/tty
  printf "This removes only:\n  /Library/Developer/CommandLineTools\n\n" > /dev/tty
  printf "macOS will request an administrator password, then open Apple’s official installer.\n" \
    > /dev/tty
  printf "Audio Delay will continue automatically when the installation is complete.\n\n" \
    > /dev/tty
  printf "Repair now? [y/N] " > /dev/tty

  local reply=""
  IFS= read -r reply < /dev/tty || true
  if [[ "${reply:l}" != "y" && "${reply:l}" != "yes" ]]; then
    echo "Command Line Tools repair was cancelled." >&2
    return 1
  fi

  echo "Requesting administrator approval to remove the broken Apple tools..."
  if ! /usr/bin/sudo /bin/rm -rf -- /Library/Developer/CommandLineTools; then
    echo "Command Line Tools repair was not authorized." >&2
    return 1
  fi

  echo "Opening Apple’s Command Line Tools installer..."
  /usr/bin/xcode-select --install >/dev/null 2>&1 || true
  wait_for_command_line_tools
}

if ! toolchain_commands_exist; then
  request_command_line_tools_install
else
  toolchain_status=0
  toolchain_is_healthy || toolchain_status=$?
  if (( toolchain_status != 0 )); then
    diagnostic_status=0
    "$SCRIPT_DIR/scripts/check-toolchain.sh" || diagnostic_status=$?
    if (( diagnostic_status == 20 )); then
      repair_command_line_tools
    else
      exit "$diagnostic_status"
    fi
  fi
fi

"$SCRIPT_DIR/scripts/check-toolchain.sh"

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
