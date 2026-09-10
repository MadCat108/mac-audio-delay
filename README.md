<img width="317" height="209" alt="image" src="https://github.com/user-attachments/assets/8129a3e1-edbd-4d90-ac57-118103646952" /># Audio Delay for macOS

A native macOS app that plays system audio through speakers or headphones after a configurable fixed delay.

<img width="558" height="643" alt="image" src="https://github.com/user-attachments/assets/c1ef2f02-9ffa-45fe-b762-7f335836ed8e" />

## Install

Requires an **Apple Silicon Mac running macOS 14.2 or newer**. Paste this command into Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/MadCat108/mac-audio-delay/main/bootstrap.sh | zsh
```

The installer downloads the public source, requests Apple's Command Line Tools if they are missing, builds the app locally, and installs it in `~/Applications`. It does not require Xcode, Homebrew, or a virtual audio driver.

On first playback, choose **Allow** when macOS requests System Audio Recording permission. Audio Delay requests audio-only access—not screen, microphone, or camera access. If no source audio reaches the app, it shows a warning with a shortcut to the correct Privacy Settings page. Enable Audio Delay under **System Audio Recording Only**, then press Start again.

## Use

1. Open **Audio Delay**.
2. Enter a delay from 0 to 3,600 seconds.
3. Choose **All Mac Audio** or one running application.
4. Choose the playback device.
5. Optionally adjust Audio Delay's output volume or mute it.
6. Press **Start**.

All-audio mode captures every application except Audio Delay. Selected-app mode delays only that application while other Mac audio plays normally. If the selected app quits, Audio Delay waits and reconnects automatically when it reopens. If the selected playback device disconnects, Audio Delay stops safely, restores normal playback, selects the current macOS default output, and explains what happened. The app never changes the system's default output device.

The delay, source, output, and Audio Delay output volume are remembered. Mute is temporary and resets when the app restarts. These controls affect only Audio Delay—not the Mac's system volume. If a saved application is no longer running, the app returns to **All Mac Audio**. If a saved output is unavailable, it uses the current macOS default output.

The stereo meters show the effective Audio Delay playback level, including its volume and mute controls. Like standard audio peak meters, they use a logarithmic decibel scale, so their bar length is not directly proportional to the volume percentage.

The status area distinguishes buffering, playing, missing source audio, a closed selected application, a disconnected output, and a detected permission problem.

For support, open **About Audio Delay** and choose **Copy Diagnostics**. The report includes useful versions, permission and connection state, audio selections, sample rate, volume, and the last error. It does not include personal paths or a list of running applications.

Closing the window quits when audio is stopped. If delay or routing is active, Audio Delay asks for confirmation before stopping playback and restoring normal undelayed audio.

## Delay limits

The supported range is **0 to 3,600 seconds (one hour)**. Zero seconds provides direct routing without an intentional delay.

The buffer is held in memory. A one-hour stereo delay uses approximately 1.3 GiB at 48 kHz or 2.6 GiB at 96 kHz. If memory allocation fails, the app stops safely and reports the problem.

## Updating

Choose **Audio Delay → Check for Updates…**. The foreground updater downloads the latest public source, shows detailed live progress, rebuilds locally, installs the update, and reopens the app.

Audio Delay also checks quietly on every startup. It prompts only when a newer version is available; connection failures remain silent. Running the installation command again also upgrades an existing installation.

## Repairing Apple Command Line Tools

If Apple’s compiler and macOS SDK are incomplete or contain mixed versions, the installer offers a guided repair. After confirmation, it runs:

```bash
sudo rm -rf /Library/Developer/CommandLineTools
xcode-select --install
```

`sudo` requests the administrator password directly; Audio Delay never reads or stores it. Apple's official installer then opens. Audio Delay waits, verifies the new tools, and continues automatically. A restart is not normally required.

The repair is offered only for recognized Apple toolchain failures and only when the selected developer directory is exactly `/Library/Developer/CommandLineTools`. It never removes a full Xcode installation.

## Development and security

Build and test locally:

```bash
./scripts/build-app.sh
swift test
```

The built app appears at `build/Audio Delay.app`. GitHub Actions repeats the tests and full Apple Silicon build, but does not publish a prebuilt app.

- All executable code is compiled locally from this public repository.
- The app installs only in the current user's `~/Applications` directory.
- Audio capture, buffering, and playback use Apple's Core Audio APIs.
- Normal installation requires no administrator password or restart; only guided repair of an already-broken Apple toolchain requires administrator approval.
- Update diagnostics are stored at `~/Library/Logs/Audio Delay Update.log`.
- The locally built app is ad-hoc signed. Managed Macs may enforce additional organizational policies.

The one-line installer executes source from this repository. Security-conscious users should inspect `bootstrap.sh`, `install.sh`, and `scripts/` before running it.

Technical references:

- https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps
- https://developer.apple.com/documentation/coreaudio/catapmutebehavior
