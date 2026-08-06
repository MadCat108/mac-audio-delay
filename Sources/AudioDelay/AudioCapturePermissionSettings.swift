import AppKit
import Foundation

enum AudioCapturePermissionSettings {
  private static let settingsURLs = [
    "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture",
    "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
  ]

  static func open() {
    for value in settingsURLs {
      guard let url = URL(string: value) else { continue }
      if NSWorkspace.shared.open(url) { return }
    }

    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
  }
}