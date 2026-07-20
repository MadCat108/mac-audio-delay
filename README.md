# Audio Delay for macOS

A small macOS app that sends audio from VB-CABLE to speakers or headphones after a configurable fixed delay. It is designed for secure browser streams that cannot be opened directly by VLC or another player.

The tested signal path is:

```text
Browser/system audio → VB-CABLE → bundled SoX → selected physical output
```

## Supported Macs

- macOS 14 Sonoma or newer
- Apple Silicon
- Standard two-channel VB-CABLE for macOS

## Recipient installation

The recipient uses one command:

```bash
/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/MadCat108/mac-audio-delay/main/bootstrap.sh)"
```

The bootstrap script:

1. Downloads this repository's source over HTTPS.
2. Requests Apple's Command Line Tools through the normal macOS installer if they are missing.
3. Downloads the unchanged official VB-CABLE package and verifies its pinned SHA-256 checksum, Apple notarization, and developer signature.
4. Displays VB-Audio's identity, donationware notice, and licensing links and requires explicit agreement.
5. Installs VB-CABLE silently after the user approves the standard macOS administrator popup.
6. Downloads and verifies the official SoX 14.4.2 source, then builds a minimal CoreAudio-only helper locally.
7. Builds and ad-hoc signs `Audio Delay.app` locally and installs it into `~/Applications`.

The recipient does not need Xcode, Homebrew, or an Apple Developer account. Apple's smaller Command Line Tools package is sufficient. On first use, the recipient must approve the normal macOS audio-input permission popup. If they deny it, macOS requires them to re-enable access manually in System Settings.

## Everyday use

1. Open **Audio Delay**.
2. Enter the delay in seconds.
3. Select speakers, headphones, or another physical output.
4. Press **Start**.

The app temporarily chooses VB-CABLE as the system output and restores the original output when stopped or closed. All system audio is routed through the delay while it is running.

## Local or maintainer build

The local build requires Xcode or matching Apple Command Line Tools. SoX is downloaded from its official SourceForge release, verified, and compiled locally without Homebrew.

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

For a short live test, choose a five-second delay in the app. Start with disposable browser audio before using an important stream.

## VB-CABLE download and licensing

VB-CABLE is not committed to or rehosted by this repository. The installer downloads the unchanged standard package from VB-Audio’s official server. Its pinned archive checksum is:

```text
e46b41c6876995403cb1da37d7c0d566f59edd83aa9fcbcdc3a205eb0b6e05c7
```

VB-CABLE is donationware; users must be able to identify its origin and donate or purchase a license. Professional and organizational use may require a paid license. The standard package's current distribution terms permit silent installation when the donationware model remains visible. The installer therefore shows the notice and requires agreement before requesting administrator authorization.

- Product: https://vb-audio.com/Cable/
- Licensing: https://vb-audio.com/Services/licensing.htm

The paid VB-CABLE A+B and C+D packages are not used or distributed.

## Security model

- The app installs only in the current user’s `~/Applications` directory.
- The app executable and SoX helper are compiled locally from source.
- The SoX and VB-CABLE downloads use HTTPS and pinned SHA-256 checksums.
- The VB-CABLE package must be notarized by Apple and signed by `Developer ID Installer: Vincent Burel (6K8JQXLBSY)`.
- No terminal `sudo` password prompt is used. VB-CABLE's required system installation uses the standard macOS administrator-approval dialog.
- VB-CABLE is installed only after the user sees its origin, donationware status, and licensing links and explicitly agrees.
- The locally built app is ad-hoc signed. Organization-managed Macs may still impose additional application-control policies.

The one-line bootstrap executes source obtained from this public repository. Security-conscious users should inspect `bootstrap.sh`, `install.sh`, and the scripts under `scripts/` before running it.
