#!/bin/zsh

set -euo pipefail

APP="$HOME/Applications/Audio Delay.app"

if [[ ! -d "$APP" ]]; then
    echo "Audio Delay is not installed in $HOME/Applications."
    exit 0
fi

osascript -e 'tell application "Audio Delay" to quit' 2>/dev/null || true
mv "$APP" "$HOME/.Trash/Audio Delay.app"
echo "Moved Audio Delay to the Trash. VB-CABLE was left installed."
