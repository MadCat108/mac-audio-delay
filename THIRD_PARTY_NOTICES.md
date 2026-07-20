# Third-party notices

## SoX

Audio Delay launches a bundled copy of SoX as a separate process for Core Audio capture, playback, and buffering. The setup downloads the official SoX 14.4.2 source archive, verifies SHA-256 `b45f598643ffbd8e363ff24d61166ccec4836fea6d3888881b8df53e3bb55f6c`, and compiles a minimal static CoreAudio-only executable locally.

- Project: https://sox.sourceforge.net/
- Source: https://downloads.sourceforge.net/project/sox/sox/14.4.2/sox-14.4.2.tar.gz
- License: GPL-2.0-or-later and LGPL-2.1-or-later components

The app bundle includes SoX's `LICENSE.GPL`, `LICENSE.LGPL`, and `COPYING` files under `Audio Delay.app/Contents/Resources/licenses/sox/`. The minimal helper links only to Apple system libraries.

## VB-CABLE

VB-CABLE is a separate prerequisite supplied by VB-Audio Software. It is not part of this repository or application bundle. Setup downloads the unchanged official package directly from VB-Audio, verifies its checksum, notarization, and expected developer identity, displays its donationware notice, and installs it only after explicit user agreement and macOS administrator authorization.

- Product and official download: https://vb-audio.com/Cable/
- Licensing and distribution terms: https://vb-audio.com/Services/licensing.htm

VB-CABLE is donationware. Users must be able to identify its origin and donate or purchase a license if appropriate. Professional and organizational use may require a paid license.
