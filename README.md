# Audio Delay for macOS

A small native macOS app that plays system audio through speakers or headphones after a configurable fixed delay. It is designed for secure browser streams that cannot be opened directly by VLC or another player.

The signal path is entirely native:

```text
Browser/system audio → private Core Audio tap → delay buffer → selected physical output
```

Audio Delay does not require Homebrew, an audio driver, an administrator password, or a restart.

## Supported Macs

- macOS 14.2 Sonoma or newer
- Apple Silicon

## Recipient installation

The recipient uses one command:

```bash
curl -fsSL https://raw.githubusercontent.com/MadCat108/mac-audio-delay/main/bootstrap.sh | zsh
```

The bootstrap script:

1. Downloads this repository's source over HTTPS.
2. Requests Apple's Command Line Tools through the normal macOS installer if they are missing.
3. Builds the Swift app and native Core Audio engine locally.
4. Ad-hoc signs the locally built app and installs it into `~/Applications`.

The recipient does not need Xcode, Homebrew, an Apple Developer account, an audio driver, or administrator access. Apple's smaller Command Line Tools package is sufficient.

On first playback, macOS displays its normal system-audio recording permission popup. Choose **Allow**. macOS remembers the choice. If access is denied, it must be re-enabled manually under **System Settings → Privacy & Security → Screen & System Audio Recording**.

## Everyday use

1. Open **Audio Delay**.
2. Enter the delay in seconds.
3. Select speakers, headphones, or another physical output.
4. Press **Start**.
5. Approve the system-audio permission popup on first use.

The app captures system audio using an Apple Core Audio process tap. The immediate copy is muted while the tap is active, and the app's own delayed output is excluded from capture to prevent feedback. The system's selected output does not change.

## Updating

Choose **Audio Delay → Check for Updates…** for an immediate manual check. When an update is available, the app opens a foreground updater with live status and progress, then closes. The updater downloads the latest public source, rebuilds the app locally, replaces the previous copy, and reopens it automatically.

Audio Delay also performs a quiet update check on startup when it has not checked successfully within the previous 24 hours. It prompts only when a newer version is available; up-to-date results and temporary network failures remain silent.

The current release version is stored in `VERSION`. Existing installations can also upgrade by running the installation command again.

## Local or maintainer build

The local build requires Xcode or matching Apple Command Line Tools:

```bash
./scripts/build-app.sh
```

The application appears at:

```text
build/Audio Delay.app
```

GitHub Actions repeats the unit tests and full local app build on an Apple Silicon runner. It does not publish a prebuilt app; recipients build from source to avoid downloaded-app Gatekeeper and notarization requirements.

## Local testing

```bash
swift test
```

For a short live test, choose a five-second delay in the app. Start with disposable browser audio before using an important stream. Confirm the exact secure stream works before removing an already-installed virtual audio driver, because some DRM-protected sources may refuse system-audio capture.

## Security model

- The app installs only in the current user's `~/Applications` directory.
- All executable code is compiled locally from the public source in this repository.
- Runtime audio capture, buffering, and playback use only Apple Core Audio APIs.
- No administrator password, privileged installer, system audio driver, or restart is required.
- In-app updates use the same public source bootstrap as the original installation and keep a diagnostic log at `~/Library/Logs/Audio Delay Update.log`.
- The locally built app is ad-hoc signed. Organization-managed Macs may still impose additional application-control policies.

The one-line bootstrap executes source obtained from this public repository. Security-conscious users should inspect `bootstrap.sh`, `install.sh`, and the scripts under `scripts/` before running it.

## Native API reference

The implementation follows Apple's Core Audio process-tap architecture:

- https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps
- https://developer.apple.com/documentation/coreaudio/catapmutebehavior
